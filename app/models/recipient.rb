# frozen_string_literal: true

class Recipient < ApplicationRecord
  belongs_to :user
  has_one :recipient_key, dependent: :destroy
  has_many :message_recipients, dependent: :destroy
  has_many :messages, through: :message_recipients
  has_many :delivery_tokens, dependent: :destroy

  enum :state, {
    invited: "invited",
    accepted: "accepted"
  }, default: :invited

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :normalize_email

  scope :with_keys, -> { accepted.joins(:recipient_key) }

  # Generate invite token and set expiration
  def generate_invite_token!
    raw_token = SecureRandom.urlsafe_base64(32)

    update!(
      invite_token_digest: self.class.digest(raw_token),
      invite_sent_at: Time.current,
      invite_expires_at: AppConfig.invite_token_ttl_days.days.from_now
    )

    raw_token
  end

  # Find recipient by raw invite token
  def self.find_by_invite_token(raw_token)
    return nil if raw_token.blank?

    find_by(invite_token_digest: digest(raw_token))
  end

  # Check if invite is still valid
  def invite_valid?
    invited? &&
      invite_token_digest.present? &&
      invite_expires_at.present? &&
      invite_expires_at > Time.current
  end

  # Accept the invite and store the public key
  def accept!(public_key_b64u:, kdf_salt_b64u:, kdf_params:)
    transaction do
      create_recipient_key!(
        public_key_b64u: public_key_b64u,
        kdf_salt_b64u: kdf_salt_b64u,
        kdf_params: kdf_params
      )

      update!(
        state: :accepted,
        accepted_at: Time.current,
        invite_token_digest: nil # Invalidate token after use
      )
    end
  end

  # Check if recipient has a valid key for encryption
  def can_receive_messages?
    accepted? && recipient_key.present?
  end

  # Display name (fallback to email)
  def display_name
    name.presence || email
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
