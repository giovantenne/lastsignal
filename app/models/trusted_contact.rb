# frozen_string_literal: true

class TrustedContact < ApplicationRecord
  belongs_to :user

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :user_id, uniqueness: true
  validates :pause_duration_hours,
            numericality: {
              only_integer: true
            },
            allow_nil: true

  before_validation :normalize_email

  validate :pause_duration_days_range

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

  def pause_active?(now: Time.current)
    paused_until.present? && paused_until > now
  end

  def effective_pause_duration_hours
    pause_duration_hours || AppConfig.trusted_contact_default_pause_duration_hours
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def pause_duration_days_range
    validate_days_range(
      value: pause_duration_hours,
      min_hours: AppConfig.trusted_contact_min_pause_duration_hours,
      max_hours: AppConfig.trusted_contact_max_pause_duration_hours,
      attribute: :pause_duration_days
    )
  end

  def validate_days_range(value:, min_hours:, max_hours:, attribute:)
    return if value.nil?

    min_days = (min_hours / 24.0).round
    max_days = (max_hours / 24.0).round

    if value < min_hours
      errors.add(attribute, "must be at least #{min_days} days")
    elsif value > max_hours
      errors.add(attribute, "must be at most #{max_days} days")
    end
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
