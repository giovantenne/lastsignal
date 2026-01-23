# frozen_string_literal: true

class User < ApplicationRecord
  # State machine: active -> grace -> cooldown -> delivered
  # Panic revoke can return from any state to active
  # Paused: user manually paused check-ins (or via emergency stop)
  enum :state, {
    active: "active",
    grace: "grace",
    cooldown: "cooldown",
    delivered: "delivered",
    paused: "paused"
  }, default: :active

  # Associations
  has_many :magic_link_tokens, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :recipients, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_one :trusted_contact, dependent: :destroy

  # Validations
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :checkin_interval_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: ->(u) { AppConfig.checkin_min_interval_hours },
              less_than_or_equal_to: ->(u) { AppConfig.checkin_max_interval_hours }
            },
            allow_nil: true

  validates :grace_period_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: ->(u) { AppConfig.checkin_min_grace_hours },
              less_than_or_equal_to: ->(u) { AppConfig.checkin_max_grace_hours }
            },
            allow_nil: true

  validates :cooldown_period_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: ->(u) { AppConfig.checkin_min_cooldown_hours },
              less_than_or_equal_to: ->(u) { AppConfig.checkin_max_cooldown_hours }
            },
            allow_nil: true

  # Callbacks
  before_validation :normalize_email
  before_create :set_default_intervals
  after_create :schedule_first_checkin
  after_create :generate_recovery_code!

  accepts_nested_attributes_for :trusted_contact,
                                allow_destroy: true,
                                reject_if: :trusted_contact_blank?

  # Scopes for check-in processing
  scope :with_active_messages, -> {
    joins(messages: { message_recipients: { recipient: :recipient_key } })
      .merge(Recipient.accepted)
      .distinct
  }

  scope :needing_grace_notification, -> {
    where(state: :active)
      .where("next_checkin_at <= ?", Time.current)
  }

  scope :needing_cooldown_transition, -> {
    where(state: :grace)
      .where("#{datetime_add_hours_sql("grace_started_at", "COALESCE(grace_period_hours, #{AppConfig.checkin_default_grace_hours})")} <= ?",
             Time.current)
  }

  scope :needing_delivery, -> {
    where(state: :cooldown)
      .where("#{datetime_add_hours_sql("cooldown_started_at", "COALESCE(cooldown_period_hours, #{AppConfig.checkin_default_cooldown_hours})")} <= ?",
             Time.current)
  }

  def self.datetime_add_hours_sql(column, hours_sql)
    adapter = connection.adapter_name.downcase
    if adapter.include?("sqlite")
      "datetime(#{column}, '+' || #{hours_sql} || ' hours')"
    else
      "#{column} + (#{hours_sql} * INTERVAL '1 hour')"
    end
  end

  # Instance methods for check-in timing
  def effective_checkin_interval_hours
    checkin_interval_hours || AppConfig.checkin_default_interval_hours
  end

  def effective_grace_period_hours
    grace_period_hours || AppConfig.checkin_default_grace_hours
  end

  def effective_cooldown_period_hours
    cooldown_period_hours || AppConfig.checkin_default_cooldown_hours
  end

  def has_active_messages?
    messages.joins(message_recipients: { recipient: :recipient_key })
      .merge(Recipient.accepted)
      .exists?
  end

  # Check-in confirmation resets the cycle
  def confirm_checkin!
    update!(
      state: :active,
      last_checkin_confirmed_at: Time.current,
      next_checkin_at: Time.current + effective_checkin_interval_hours.hours,
      checkin_reminder_sent_at: nil,
      grace_warning_sent_at: nil,
      cooldown_warning_sent_at: nil,
      delivery_notice_sent_at: nil,
      grace_started_at: nil,
      cooldown_started_at: nil,
      delivered_at: nil,
      checkin_token_digest: nil,
      checkin_token_expires_at: nil,
      panic_token_digest: nil,
      panic_token_expires_at: nil
    )
  end

  # State transition: active -> grace
  def enter_grace!
    return unless active?

    update!(
      state: :grace,
      grace_started_at: Time.current,
      checkin_reminder_sent_at: nil,
      grace_warning_sent_at: nil
    )
  end

  # State transition: grace -> cooldown
  def enter_cooldown!
    return unless grace?

    update!(
      state: :cooldown,
      cooldown_started_at: Time.current,
      checkin_token_digest: nil,
      checkin_token_expires_at: nil
    )
  end

  # State transition: cooldown -> delivered
  def mark_delivered!
    return unless cooldown?

    update!(
      state: :delivered,
      delivered_at: Time.current,
      panic_token_digest: nil,
      panic_token_expires_at: nil,
      checkin_token_digest: nil,
      checkin_token_expires_at: nil
    )
  end

  # Panic revoke: return to active state from any state
  def panic_revoke!
    return if active? || paused?

    confirm_checkin!
  end

  # Emergency stop using recovery code (no email required)
  # Sets state to paused since user likely lost email access
  def emergency_stop!
    return if paused?

    update!(
      state: :paused,
      grace_started_at: nil,
      cooldown_started_at: nil,
      next_checkin_at: nil,
      checkin_token_digest: nil,
      checkin_token_expires_at: nil,
      panic_token_digest: nil,
      panic_token_expires_at: nil
    )
  end

  # Pause check-ins (manual or via emergency stop)
  def pause!
    return if paused? || delivered?

    update!(
      state: :paused,
      grace_started_at: nil,
      cooldown_started_at: nil,
      next_checkin_at: nil,
      checkin_token_digest: nil,
      checkin_token_expires_at: nil,
      panic_token_digest: nil,
      panic_token_expires_at: nil
    )
  end

  # Resume check-ins (requires login, proving email access)
  def unpause!
    return unless paused?

    confirm_checkin!
  end

  def resume_checkins_for_messages!
    return if paused? || delivered?

    confirm_checkin!
  end

  # Calculate when grace period ends
  def grace_ends_at
    return nil unless grace_started_at

    grace_started_at + effective_grace_period_hours.hours
  end

  # Calculate when cooldown period ends
  def cooldown_ends_at
    return nil unless cooldown_started_at

    cooldown_started_at + effective_cooldown_period_hours.hours
  end

  def trusted_contact_pause_active?
    trusted_contact&.pause_active? || false
  end

  # Recovery code methods
  # Generate a new recovery code (returns plaintext, stores digest)
  # Format: XXXX-XXXX-XXXX-XXXX (16 alphanumeric chars, grouped)
  def generate_recovery_code!
    # Generate 16 random alphanumeric characters (case-insensitive for usability)
    raw_code = SecureRandom.alphanumeric(16).upcase
    formatted_code = raw_code.scan(/.{4}/).join("-")

    # Store digest (same pattern as tokens)
    self.recovery_code_digest = Digest::SHA256.hexdigest(raw_code)
    self.recovery_code_viewed_at = nil
    save!

    formatted_code
  end

  # Verify a recovery code (returns true/false, does NOT invalidate)
  def verify_recovery_code(code)
    return false if recovery_code_digest.blank?

    # Normalize: remove dashes, uppercase
    normalized = code.to_s.gsub("-", "").upcase
    digest = Digest::SHA256.hexdigest(normalized)

    ActiveSupport::SecurityUtils.secure_compare(digest, recovery_code_digest)
  end

  # Use recovery code for emergency stop (verifies, stops, regenerates)
  # Returns new recovery code on success, nil on failure
  def use_recovery_code!(code)
    return nil unless verify_recovery_code(code)

    emergency_stop!
    generate_recovery_code!
  end

  # Check if user has seen their recovery code
  def recovery_code_viewed?
    recovery_code_viewed_at.present?
  end

  # Mark recovery code as viewed
  def mark_recovery_code_viewed!
    update!(recovery_code_viewed_at: Time.current) unless recovery_code_viewed?
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def trusted_contact_blank?(attrs)
    attrs.values.all?(&:blank?)
  end

  def set_default_intervals
    # nil means "use system defaults" - we don't need to set explicit values
    # The effective_* methods handle this
  end

  def schedule_first_checkin
    self.update_column(:next_checkin_at, Time.current + effective_checkin_interval_hours.hours)
  end
end
