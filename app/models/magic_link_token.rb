# frozen_string_literal: true

class MagicLinkToken < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :unused, -> { where(used_at: nil) }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :valid_tokens, -> { unused.not_expired }

  # Generate a new magic link token for a user
  # Returns the raw token (to be sent via email) and saves the digest
  def self.generate_for(user, request: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    token_digest = digest(raw_token)

    token = create!(
      user: user,
      token_digest: token_digest,
      expires_at: AppConfig.magic_link_ttl_minutes.minutes.from_now,
      ip_hash: request ? hash_ip(request.remote_ip) : nil,
      user_agent_hash: request ? hash_user_agent(request.user_agent) : nil
    )

    [ token, raw_token ]
  end

  # Find a token by its raw value and verify it's valid
  # Returns the token if valid, nil otherwise
  def self.find_and_verify(raw_token)
    return nil if raw_token.blank?

    token_digest = digest(raw_token)
    token = valid_tokens.find_by(token_digest: token_digest)

    return nil unless token

    token
  end

  # Mark the token as used
  def mark_used!
    update!(used_at: Time.current)
  end

  def used?
    used_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def valid_token?
    !used? && !expired?
  end

  private

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def self.hash_ip(ip)
    return nil if ip.blank?

    # Hash IP for privacy while still allowing abuse detection
    Digest::SHA256.hexdigest("#{ip}:#{Rails.application.secret_key_base}")
  end

  def self.hash_user_agent(user_agent)
    return nil if user_agent.blank?

    # Simple hash for fingerprinting
    Digest::SHA256.hexdigest(user_agent.to_s)[0..15]
  end

  # Clean up expired tokens periodically (can be called from a job)
  def self.cleanup_expired!(older_than: 24.hours.ago)
    where("expires_at < ?", older_than).delete_all
  end
end
