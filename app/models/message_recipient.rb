# frozen_string_literal: true

class MessageRecipient < ApplicationRecord
  belongs_to :message
  belongs_to :recipient

  validates :encrypted_msg_key_b64u, presence: true
  validates :envelope_algo, presence: true
  validates :envelope_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :message_id, uniqueness: { scope: :recipient_id }
  validates :delivery_delay_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: ->(mr) { AppConfig.message_recipient_max_delivery_delay_days * 24 },
              message: ->(object, data) {
                max_days = AppConfig.message_recipient_max_delivery_delay_days
                "must be at most #{max_days} #{'day'.pluralize(max_days)}"
              }
            },
            allow_nil: true

  # Validate recipient has a key
  validate :recipient_has_key

  # Returns the datetime when this message becomes available to the recipient
  # Returns nil if the user hasn't been delivered yet
  def available_at
    delivered_at = message&.user&.delivered_at
    return nil unless delivered_at

    delivered_at + (delivery_delay_hours || 0).hours
  end

  # Returns true if the message is currently available to the recipient
  def available?
    return true if delivery_delay_hours.nil? || delivery_delay_hours.zero?

    avail = available_at
    avail.present? && Time.current >= avail
  end

  # Returns the delay in days (for display purposes)
  def delivery_delay_days
    (delivery_delay_hours || 0) / 24
  end

  private

  def recipient_has_key
    return if recipient.blank?

    unless recipient.can_receive_messages?
      errors.add(:recipient, "must have accepted invite and registered a public key")
    end
  end
end
