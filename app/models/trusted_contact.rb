# frozen_string_literal: true

class TrustedContact < ApplicationRecord
  belongs_to :user

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :user_id, uniqueness: true
  validates :ping_interval_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: ->(_) { AppConfig.trusted_contact_min_ping_interval_hours },
              less_than_or_equal_to: ->(_) { AppConfig.trusted_contact_max_ping_interval_hours }
            },
            allow_nil: true
  validates :pause_duration_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: ->(_) { AppConfig.trusted_contact_min_pause_duration_hours },
              less_than_or_equal_to: ->(_) { AppConfig.trusted_contact_max_pause_duration_hours }
            },
            allow_nil: true

  before_validation :normalize_email

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    contact = find_by(token_digest: digest(raw_token))
    return nil unless contact
    return nil if contact.token_expires_at.blank? || contact.token_expires_at <= Time.current

    contact
  end

  def generate_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(
      token_digest: self.class.digest(raw_token),
      token_expires_at: AppConfig.trusted_contact_token_ttl_hours.hours.from_now
    )

    raw_token
  end

  def confirm!
    update!(
      last_confirmed_at: Time.current,
      paused_until: Time.current + effective_pause_duration_hours.hours,
      token_digest: nil,
      token_expires_at: nil
    )
  end

  def ping_due?(now: Time.current)
    return false unless user.grace? || user.cooldown?
    return false if paused_until.present? && paused_until > now

    last_pinged_at.nil? || last_pinged_at <= now - effective_ping_interval_hours.hours
  end

  def pause_active?(now: Time.current)
    paused_until.present? && paused_until > now
  end

  def effective_ping_interval_hours
    ping_interval_hours || AppConfig.trusted_contact_default_ping_interval_hours
  end

  def effective_pause_duration_hours
    pause_duration_hours || AppConfig.trusted_contact_default_pause_duration_hours
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
