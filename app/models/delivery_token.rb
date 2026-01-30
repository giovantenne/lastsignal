# frozen_string_literal: true

class DeliveryToken < ApplicationRecord
  belongs_to :recipient

  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  # Generate a new delivery token for a recipient
  def self.generate_for(recipient)
    raw_token = SecureRandom.urlsafe_base64(32)

    token = create!(
      recipient: recipient,
      token_digest: digest(raw_token)
    )

    [ token, raw_token ]
  end

  # Find a token by its raw value
  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def record_access!
    update!(last_accessed_at: Time.current)
  end

  private

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
