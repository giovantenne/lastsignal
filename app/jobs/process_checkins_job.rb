# frozen_string_literal: true

class ProcessCheckinsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[ProcessCheckinsJob] Starting check-in processing"

    # Track users who received an email this iteration (one email per user per run)
    @processed_user_ids = Set.new

    process_initial_attempts
    process_followup_attempts
    process_trusted_contact_pings
    process_delivery

    Rails.logger.info "[ProcessCheckinsJob] Completed check-in processing"
  end

  private

  def process_initial_attempts
    users = User.with_active_messages.needing_initial_attempt

    users.find_each do |user|
      with_user_lock(user) do
        next if @processed_user_ids.include?(user.id)
        next unless user.active?
        next unless user.has_active_messages?
        next if user.next_checkin_at.nil?
        next unless user.next_checkin_at <= Time.current
        next if user.checkin_attempts_sent.to_i.positive?

        send_attempt(user)
        @processed_user_ids.add(user.id)
      end
    end
  end

  def process_followup_attempts
    users = User.with_active_messages.needing_followup_attempt

    users.find_each do |user|
      with_user_lock(user) do
        next if @processed_user_ids.include?(user.id)
        next unless user.active? || user.grace? || user.cooldown?
        next unless user.has_active_messages?
        next if user.next_attempt_due_at.nil? || user.next_attempt_due_at > Time.current

        # Don't send more attempts if we've already reached the max
        next if user.checkin_attempts_sent.to_i >= user.effective_checkin_attempts

        send_attempt(user)
        @processed_user_ids.add(user.id)
      end
    end
  end

  def process_delivery
    users = User.with_active_messages.needing_delivery

    users.find_each do |user|
      with_user_lock(user) do
        next if @processed_user_ids.include?(user.id)
        next unless user.cooldown?
        next unless user.has_active_messages?
        next if user.delivery_due_at.nil? || user.delivery_due_at > Time.current

        if user.trusted_contact_pause_active?
          Rails.logger.info "[ProcessCheckinsJob] User #{user.id} delivery blocked by trusted contact pause"
          contact = user.trusted_contact

          safe_audit_log(
            action: "delivery_blocked_by_trusted_contact",
            user: user,
            actor_type: "system",
            metadata: {
              trusted_contact_id: contact&.id,
              paused_until: contact&.paused_until&.iso8601,
              delivery_due_at: user.delivery_due_at&.iso8601
            }
          )
          next
        end

        Rails.logger.info "[ProcessCheckinsJob] User #{user.id} delivery due, triggering delivery"

        user.mark_delivered!

        DeliverMessagesJob.perform_later(user.id)

        next if user.delivery_notice_sent_at.present?

        # Get emails of recipients who have keys and at least one message from this user
        recipient_ids_with_messages = user.messages.joins(:message_recipients)
                                          .pluck("message_recipients.recipient_id")
                                          .uniq

        recipients = user.recipients.with_keys
                         .where(id: recipient_ids_with_messages)
                         .pluck(:email)

        CheckinMailer.delivery_notice(user, recipients).deliver_later

        user.update_column(:delivery_notice_sent_at, Time.current)

        safe_audit_log(
          action: "delivery_notice_sent",
          user: user,
          actor_type: "system",
          metadata: { delivered_at: user.delivered_at&.iso8601, recipients_count: recipients.size }
        )

        safe_audit_log(
          action: "state_to_delivered",
          user: user,
          actor_type: "system",
          metadata: { delivered_at: user.delivered_at&.iso8601 }
        )
      end
    end
  end

  def process_trusted_contact_pings
    contacts = TrustedContact.joins(:user)
      .merge(User.with_active_messages)
      .where(users: { state: "cooldown" })

    contacts.find_each do |contact|
      with_contact_lock(contact) do
        user = contact.user
        next unless user.has_active_messages?
        next if contact.pause_active?
        next if user.cooldown_warning_sent_at.nil?

        # Ping if never pinged, or if pinged before the current cooldown started
        should_ping = contact.last_pinged_at.nil? || contact.last_pinged_at < user.cooldown_warning_sent_at

        # Also ping if a previous pause just expired (paused_until is in the past and we haven't pinged since)
        pause_just_expired = contact.paused_until.present? &&
                             contact.paused_until <= Time.current &&
                             (contact.last_pinged_at.nil? || contact.last_pinged_at < contact.paused_until)

        should_ping ||= pause_just_expired

        next unless should_ping

        send_trusted_contact_ping(contact)
        user.update_column(:cooldown_warning_sent_at, Time.current) if pause_just_expired
      end
    end
  end

  def send_attempt(user)
    attempt_total = user.effective_checkin_attempts
    previous_attempts = user.checkin_attempts_sent.to_i
    attempt_number = previous_attempts + 1
    now = Time.current
    entering_cooldown = previous_attempts < attempt_total && attempt_number >= attempt_total

    # State transitions:
    # - First reminder (attempt 1): stays in active
    # - Second reminder (attempt 2+): moves to grace
    # - Final reminder (attempt = total): moves to cooldown
    new_state = if attempt_number >= attempt_total
                  :cooldown
    elsif attempt_number == 1
                  :active
    else
                  :grace
    end

    user.update_columns(
      state: new_state,
      last_checkin_attempt_at: now,
      checkin_attempts_sent: attempt_number,
      cooldown_warning_sent_at: (entering_cooldown && user.cooldown_warning_sent_at.nil? ? now : user.cooldown_warning_sent_at)
    )

    raw_token = generate_checkin_token(user)
    if attempt_number >= attempt_total
      CheckinMailer.cooldown_warning(user, raw_token, attempt_number:, attempt_total:).deliver_later
    elsif attempt_number == 1
      CheckinMailer.reminder(user, raw_token, attempt_number:, attempt_total:).deliver_later
    else
      CheckinMailer.grace_period_warning(user, raw_token, attempt_number:, attempt_total:).deliver_later
    end

    log_attempt_audit(user, attempt_number:, attempt_total:)

    if entering_cooldown
      contact = user.trusted_contact
      send_trusted_contact_ping(contact) if contact.present? && !contact.pause_active?
    end
  end

  def log_attempt_audit(user, attempt_number:, attempt_total:)
    if attempt_number == 1
      # First reminder: stays in active state
      safe_audit_log(
        action: "checkin_reminder_sent",
        user: user,
        actor_type: "system",
        metadata: { next_checkin_at: user.next_checkin_at&.iso8601 }
      )
    elsif attempt_number == 2
      # Second reminder: transitions to grace
      safe_audit_log(
        action: "grace_warning_sent",
        user: user,
        actor_type: "system",
        metadata: { attempt_number: attempt_number }
      )

      safe_audit_log(
        action: "state_to_grace",
        user: user,
        actor_type: "system",
        metadata: { attempt_number: attempt_number }
      )
    elsif attempt_number < attempt_total
      safe_audit_log(
        action: "grace_warning_sent",
        user: user,
        actor_type: "system",
        metadata: { attempt_number: attempt_number }
      )
    else
      safe_audit_log(
        action: "cooldown_warning_sent",
        user: user,
        actor_type: "system",
        metadata: { delivery_due_at: user.delivery_due_at&.iso8601, attempt_number: attempt_number }
      )

      if attempt_number == attempt_total
        safe_audit_log(
          action: "state_to_cooldown",
          user: user,
          actor_type: "system",
          metadata: { attempt_number: attempt_number }
        )
      end
    end
  end

  def send_trusted_contact_ping(contact)
    raw_token = contact.generate_token!

    TrustedContactMailer.ping(contact, raw_token).deliver_later
    TrustedContactMailer.ping_notice(contact.user, contact).deliver_later

    contact.update!(last_pinged_at: Time.current)

    safe_audit_log(
      action: "trusted_contact_ping_sent",
      user: contact.user,
      actor_type: "system",
      metadata: { trusted_contact_id: contact.id, pinged_at: contact.last_pinged_at&.iso8601 }
    )

    safe_audit_log(
      action: "trusted_contact_ping_notice_sent",
      user: contact.user,
      actor_type: "system",
      metadata: { trusted_contact_id: contact.id }
    )
  end

  def generate_checkin_token(user)
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    user.update_columns(checkin_token_digest: token_digest)

    raw_token
  end

  def with_user_lock(user)
    User.transaction do
      user.lock!
      yield
    end
  end

  def with_contact_lock(contact)
    TrustedContact.transaction do
      contact.lock!
      yield
    end
  end

  def safe_audit_log(**args)
    AuditLog.log(**args)
  rescue StandardError => e
    Rails.logger.error("[ProcessCheckinsJob] AuditLog failed: #{e.class}: #{e.message}")
  end
end
