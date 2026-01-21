# frozen_string_literal: true

class ProcessCheckinsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "[ProcessCheckinsJob] Starting check-in processing"

    process_missed_checkins
    process_grace_expirations
    process_trusted_contact_pings
    process_cooldown_expirations

    Rails.logger.info "[ProcessCheckinsJob] Completed check-in processing"
  end

  private

  # Users who missed their check-in: active -> grace
  def process_missed_checkins
    users = User.needing_grace_notification.lock

    users.find_each do |user|
      Rails.logger.info "[ProcessCheckinsJob] User #{user.id} missed check-in, entering grace period"

      user.enter_grace!

      # Send grace period notification
      CheckinMailer.grace_period_warning(user).deliver_later

      AuditLog.log(
        action: "state_to_grace",
        user: user,
        actor_type: "system",
        metadata: { grace_ends_at: user.grace_ends_at&.iso8601 }
      )
    end
  end

  # Users whose grace period expired: grace -> cooldown
  def process_grace_expirations
    users = User.needing_cooldown_transition.lock

    users.find_each do |user|
      Rails.logger.info "[ProcessCheckinsJob] User #{user.id} grace expired, entering cooldown"

      user.enter_cooldown!

      # Generate panic revoke token and send email
      raw_token = generate_panic_token(user)
      CheckinMailer.cooldown_warning(user, raw_token).deliver_later

      AuditLog.log(
        action: "state_to_cooldown",
        user: user,
        actor_type: "system",
        metadata: { cooldown_ends_at: user.cooldown_ends_at&.iso8601 }
      )
    end
  end

  def process_trusted_contact_pings
    contacts = TrustedContact.joins(:user)
      .where(users: { state: %w[grace cooldown] })
      .lock

    contacts.find_each do |contact|
      next unless contact.ping_due?

      raw_token = contact.generate_token!
      contact.update!(last_pinged_at: Time.current)

      TrustedContactMailer.ping(contact, raw_token).deliver_later
      TrustedContactMailer.ping_notice(contact.user, contact).deliver_later

      AuditLog.log(
        action: "trusted_contact_ping_sent",
        user: contact.user,
        actor_type: "system",
        metadata: { trusted_contact_id: contact.id, pinged_at: contact.last_pinged_at&.iso8601 }
      )
    end
  end

  # Users whose cooldown expired: cooldown -> delivered
  def process_cooldown_expirations
    users = User.needing_delivery.lock

    users.find_each do |user|
      if user.trusted_contact_pause_active?
        Rails.logger.info "[ProcessCheckinsJob] User #{user.id} cooldown expired but trusted contact pause is active"
        next
      end

      Rails.logger.info "[ProcessCheckinsJob] User #{user.id} cooldown expired, triggering delivery"

      user.mark_delivered!

      # Trigger message delivery
      DeliverMessagesJob.perform_async(user.id)

      AuditLog.log(
        action: "state_to_delivered",
        user: user,
        actor_type: "system",
        metadata: { delivered_at: user.delivered_at&.iso8601 }
      )
    end
  end

  def generate_panic_token(user)
    # Store panic token for verification
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    # Store in user record (we'll add this column or use a separate table)
    user.update_column(:panic_token_digest, token_digest)

    raw_token
  end
end
