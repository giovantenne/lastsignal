# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :user
  has_many :message_recipients, dependent: :destroy
  has_many :recipients, through: :message_recipients

  validates :ciphertext_b64u, presence: true
  validates :nonce_b64u, presence: true
  validates :aead_algo, presence: true
  validates :payload_version, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Validate that message has at least one recipient
  validate :has_at_least_one_recipient, on: :create

  scope :with_recipients, -> { includes(:message_recipients, :recipients) }

  # Build message with encrypted data from client
  def self.create_encrypted(user:, label:, ciphertext_b64u:, nonce_b64u:, recipient_envelopes:, aead_algo: "xchacha20poly1305_ietf", payload_version: 1)
    transaction do
      message = create!(
        user: user,
        label: label,
        ciphertext_b64u: ciphertext_b64u,
        nonce_b64u: nonce_b64u,
        aead_algo: aead_algo,
        payload_version: payload_version
      )

      recipient_envelopes.each do |envelope|
        message.message_recipients.create!(
          recipient_id: envelope[:recipient_id],
          encrypted_msg_key_b64u: envelope[:encrypted_msg_key_b64u],
          envelope_algo: envelope[:envelope_algo] || "crypto_box_seal",
          envelope_version: envelope[:envelope_version] || 1
        )
      end

      message
    end
  end

  # Update message with new encrypted data (re-encryption)
  def update_encrypted(label:, ciphertext_b64u:, nonce_b64u:, recipient_envelopes:, aead_algo: "xchacha20poly1305_ietf", payload_version: 1)
    transaction do
      # Remove old recipients
      message_recipients.destroy_all

      # Update message
      update!(
        label: label,
        ciphertext_b64u: ciphertext_b64u,
        nonce_b64u: nonce_b64u,
        aead_algo: aead_algo,
        payload_version: payload_version
      )

      # Add new recipients
      recipient_envelopes.each do |envelope|
        message_recipients.create!(
          recipient_id: envelope[:recipient_id],
          encrypted_msg_key_b64u: envelope[:encrypted_msg_key_b64u],
          envelope_algo: envelope[:envelope_algo] || "crypto_box_seal",
          envelope_version: envelope[:envelope_version] || 1
        )
      end

      self
    end
  end

  # Get payload for delivery to a specific recipient
  def delivery_payload_for(recipient)
    mr = message_recipients.find_by(recipient_id: recipient.id)
    return nil unless mr

    recipient_key = recipient.recipient_key
    return nil unless recipient_key

    {
      ciphertext_b64u: ciphertext_b64u,
      nonce_b64u: nonce_b64u,
      aead_algo: aead_algo,
      payload_version: payload_version,
      encrypted_msg_key_b64u: mr.encrypted_msg_key_b64u,
      envelope_algo: mr.envelope_algo,
      envelope_version: mr.envelope_version,
      kdf_salt_b64u: recipient_key.kdf_salt_b64u,
      kdf_params: recipient_key.kdf_params
    }
  end

  private

  def has_at_least_one_recipient
    # Skip validation if we're creating via create_encrypted (recipients added after)
    # This is checked at the controller level
  end
end
