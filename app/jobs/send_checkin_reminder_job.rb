# frozen_string_literal: true

class SendCheckinReminderJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    return unless user.active?
    return if user.next_checkin_at.nil?

    # Only send reminder if check-in is due within 24 hours
    return unless user.next_checkin_at <= 24.hours.from_now

    raw_token = generate_checkin_token(user)
    CheckinMailer.reminder(user, raw_token).deliver_later

    AuditLog.log(
      action: "checkin_reminder_sent",
      user: user,
      actor_type: "system",
      metadata: { next_checkin_at: user.next_checkin_at&.iso8601 }
    )

    Rails.logger.info "[SendCheckinReminderJob] Sent check-in reminder to user #{user_id}"
  end

  private

  def generate_checkin_token(user)
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = Digest::SHA256.hexdigest(raw_token)

    user.update_column(:checkin_token_digest, token_digest)

    raw_token
  end
end
