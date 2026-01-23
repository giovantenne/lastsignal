# frozen_string_literal: true

class SendCheckinReminderJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    User.transaction do
      user.lock!
      return unless user.active?
      return if user.next_checkin_at.nil?

      # Only send reminder if check-in is due within 24 hours
      return unless user.next_checkin_at <= 24.hours.from_now
      return unless user.next_checkin_at > Time.current

      return if user.checkin_reminder_sent_at.present?

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

      Rails.logger.info "[SendCheckinReminderJob] Sent check-in reminder to user #{user_id}"
    end
  end


  private

  def generate_checkin_token(user, expires_at:)
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    user.update_columns(
      checkin_token_digest: token_digest,
      checkin_token_expires_at: expires_at
    )

    raw_token
  end

  def safe_audit_log(**args)
    AuditLog.log(**args)
  rescue StandardError => e
    Rails.logger.error("[SendCheckinReminderJob] AuditLog failed: #{e.class}: #{e.message}")
  end
end
