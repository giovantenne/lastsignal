# frozen_string_literal: true

class MessageRecipient < ApplicationRecord
  belongs_to :message
  belongs_to :recipient

  validates :encrypted_msg_key_b64u, presence: true
  validates :envelope_algo, presence: true
  validates :envelope_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :message_id, uniqueness: { scope: :recipient_id }

  # Validate recipient has a key
  validate :recipient_has_key

  private

  def recipient_has_key
    return if recipient.blank?

    unless recipient.can_receive_messages?
      errors.add(:recipient, "must have accepted invite and registered a public key")
    end
  end
end
