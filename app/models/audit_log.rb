# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  ACTOR_TYPES = %w[user system recipient trusted_contact].freeze
  ACTIONS = %w[
    login_requested
    login_success
    logout
    recipient_invited
    recipient_accepted
    message_created
    message_updated
    message_deleted
    state_to_grace
    state_to_cooldown
    state_to_delivered
    checkin_confirmed
    checkin_paused
    checkin_resumed
    checkin_reminder_sent
    grace_warning_sent
    cooldown_warning_sent
    delivery_notice_sent
    delivery_blocked_by_trusted_contact
    emergency_stop
    delivery_link_opened
    trusted_contact_ping_sent
    trusted_contact_ping_notice_sent
    trusted_contact_confirmed
    trusted_contact_confirmation_notice_sent
    trusted_contact_token_invalid
    magic_link_sent
    recipient_invite_sent
    recipient_delivery_sent
    message_decrypted
    account_updated
    account_deleted
    checkin_resumed_for_messages
    checkin_token_invalid
    delivery_token_invalid
    invite_token_invalid
  ].freeze

  validates :actor_type, presence: true, inclusion: { in: ACTOR_TYPES }
  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_action, ->(action) { where(action: action) }

  # Create an audit log entry
  def self.log(action:, user: nil, actor_type: "user", metadata: {}, request: nil)
    user_id = user&.respond_to?(:id) ? user.id : user

    create!(
      user_id: user_id,
      actor_type: actor_type,
      action: action,
      metadata: sanitize_metadata(metadata),
      ip_hash: request ? hash_ip(request.remote_ip) : nil,
      user_agent_hash: request ? hash_user_agent(request.user_agent) : nil
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create audit log: #{e.message}")
    nil
  end

  private

  def self.sanitize_metadata(metadata)
    # Remove any sensitive keys that might accidentally be included
    sensitive_keys = %w[password passphrase token secret key private]

    metadata.deep_stringify_keys.reject do |key, _|
      sensitive_keys.any? { |s| key.to_s.downcase.include?(s) }
    end
  end

  def self.hash_ip(ip)
    return nil if ip.blank?
    Digest::SHA256.hexdigest("#{ip}:#{Rails.application.secret_key_base}")[0..15]
  end

  def self.hash_user_agent(user_agent)
    return nil if user_agent.blank?
    Digest::SHA256.hexdigest(user_agent.to_s)[0..15]
  end
end
