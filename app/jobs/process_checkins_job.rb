# frozen_string_literal: true

class ProcessCheckinsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[ProcessCheckinsJob] Starting check-in processing"

    process_due_reminders
    process_missed_checkins
    process_grace_expirations
    process_trusted_contact_pings
    process_cooldown_expirations

    Rails.logger.info "[ProcessCheckinsJob] Completed check-in processing"
  end

  private

  # Users with check-ins due soon: send reminder
  def process_due_reminders
    users = User.where(state: :active)
      .where("next_checkin_at <= ? AND next_checkin_at > ?", 24.hours.from_now, Time.current)

    users.find_each do |user|
      with_user_lock(user) do
        next unless user.active?
        next if user.next_checkin_at.nil?
        next unless user.next_checkin_at <= 24.hours.from_now
        next unless user.next_checkin_at > Time.current
        next if user.checkin_reminder_sent_at.present?

        grace_ends_at = user.next_checkin_at + user.effective_grace_period_hours.hours
        raw_token = generate_checkin_token(user, expires_at: grace_ends_at)
        CheckinMailer.reminder(user, raw_token).deliver_later

        user.update_column(:checkin_reminder_sent_at, Time.current)

        safe_audit_log(
          action: "checkin_reminder_sent",
          user: user,
          actor_type: "system",
          metadata: { next_checkin_at: user.next_checkin_at&.iso8601 }
        )
      end
    end
  end

  # Users who missed their check-in: active -> grace
  def process_missed_checkins
    users = User.needing_grace_notification

    users.find_each do |user|
      with_user_lock(user) do
        next unless user.active?
        next if user.next_checkin_at.nil? || user.next_checkin_at > Time.current

        Rails.logger.info "[ProcessCheckinsJob] User #{user.id} missed check-in, entering grace period"

        user.enter_grace!

        # Send grace period notification with check-in link
        next if user.grace_warning_sent_at.present?

        raw_token = generate_checkin_token(user, expires_at: user.grace_ends_at)
        CheckinMailer.grace_period_warning(user, raw_token).deliver_later

        user.update_column(:grace_warning_sent_at, Time.current)

        safe_audit_log(
          action: "grace_warning_sent",
          user: user,
          actor_type: "system",
          metadata: { grace_ends_at: user.grace_ends_at&.iso8601 }
        )

        safe_audit_log(
          action: "state_to_grace",
          user: user,
          actor_type: "system",
          metadata: { grace_ends_at: user.grace_ends_at&.iso8601 }
        )
      end
    end
  end

  # Users whose grace period expired: grace -> cooldown
  def process_grace_expirations
    users = User.needing_cooldown_transition

    users.find_each do |user|
      with_user_lock(user) do
        next unless user.grace?
        next if user.grace_ends_at.nil? || user.grace_ends_at > Time.current

        Rails.logger.info "[ProcessCheckinsJob] User #{user.id} grace expired, entering cooldown"

        user.enter_cooldown!

        next if user.cooldown_warning_sent_at.present?

        # Generate panic revoke token and send email
        raw_token = generate_panic_token(user, expires_at: user.cooldown_ends_at)
        CheckinMailer.cooldown_warning(user, raw_token).deliver_later

        user.update_column(:cooldown_warning_sent_at, Time.current)

        safe_audit_log(
          action: "cooldown_warning_sent",
          user: user,
          actor_type: "system",
          metadata: { cooldown_ends_at: user.cooldown_ends_at&.iso8601 }
        )

        safe_audit_log(
          action: "state_to_cooldown",
          user: user,
          actor_type: "system",
          metadata: { cooldown_ends_at: user.cooldown_ends_at&.iso8601 }
        )
      end
    end
  end

  def process_trusted_contact_pings
    contacts = TrustedContact.joins(:user)
      .where(users: { state: %w[grace cooldown] })

    contacts.find_each do |contact|
      with_contact_lock(contact) do
        next unless contact.ping_due?

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
    end
  end

  # Users whose cooldown expired: cooldown -> delivered
  def process_cooldown_expirations
    users = User.needing_delivery

    users.find_each do |user|
      with_user_lock(user) do
        next unless user.cooldown?
        next if user.cooldown_ends_at.nil? || user.cooldown_ends_at > Time.current

        if user.trusted_contact_pause_active?
          Rails.logger.info "[ProcessCheckinsJob] User #{user.id} cooldown expired but trusted contact pause is active"
          contact = user.trusted_contact

          safe_audit_log(
            action: "delivery_blocked_by_trusted_contact",
            user: user,
            actor_type: "system",
            metadata: {
              trusted_contact_id: contact&.id,
              paused_until: contact&.paused_until&.iso8601,
              cooldown_ends_at: user.cooldown_ends_at&.iso8601
            }
          )
          next
        end

        Rails.logger.info "[ProcessCheckinsJob] User #{user.id} cooldown expired, triggering delivery"

        user.mark_delivered!

        # Trigger message delivery
        DeliverMessagesJob.perform_later(user.id)

        next if user.delivery_notice_sent_at.present?

        recipients = user.recipients.with_keys
          .joins(:messages)
          .where(messages: { user_id: user.id })
          .distinct
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

  def generate_panic_token(user, expires_at:)
    # Store panic token for verification
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    # Store in user record (we'll add this column or use a separate table)
    user.update_columns(
      panic_token_digest: token_digest,
      panic_token_expires_at: expires_at
    )

    raw_token
  end

  def generate_checkin_token(user, expires_at:)
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    user.update_columns(
      checkin_token_digest: token_digest,
      checkin_token_expires_at: expires_at
    )

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
