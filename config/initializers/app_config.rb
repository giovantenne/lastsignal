# frozen_string_literal: true

# Centralized application configuration loaded from environment variables
# with sensible defaults for development.

module AppConfig
  class << self
    # Application
    def app_base_url
      ENV.fetch("APP_BASE_URL", "http://localhost:3000")
    end

    # SMTP
    def smtp_host
      ENV.fetch("SMTP_HOST", "localhost")
    end

    def smtp_port
      ENV.fetch("SMTP_PORT", "1025").to_i
    end

    def smtp_user
      ENV.fetch("SMTP_USER", nil)
    end

    def smtp_pass
      ENV.fetch("SMTP_PASS", nil)
    end

    def smtp_domain
      ENV.fetch("SMTP_DOMAIN", "localhost")
    end

    def smtp_from_email
      ENV.fetch("SMTP_FROM_EMAIL", "noreply@lastsignal.app")
    end

    def smtp_from_name
      ENV.fetch("SMTP_FROM_NAME", "LastSignal")
    end

    # Authentication
    def magic_link_ttl_minutes
      AppDefaults::MAGIC_LINK_TTL_MINUTES
    end

    def allowed_emails
      ENV.fetch("ALLOWED_EMAILS", "")
        .split(",")
        .map { |email| email.strip.downcase }
        .reject(&:blank?)
    end

    def allowlist_enabled?
      allowed_emails.any?
    end

    def allowlisted_email?(email)
      return true unless allowlist_enabled?

      allowed_emails.include?(email.to_s.strip.downcase)
    end

    # Check-in defaults
    def checkin_default_interval_hours
      AppDefaults::CHECKIN_DEFAULT_INTERVAL_HOURS
    end

    def checkin_default_attempts
      AppDefaults::CHECKIN_DEFAULT_ATTEMPTS
    end

    def checkin_default_attempt_interval_hours
      AppDefaults::CHECKIN_DEFAULT_ATTEMPT_INTERVAL_HOURS
    end

    # Check-in minimum bounds
    def checkin_min_interval_hours
      AppDefaults::CHECKIN_MIN_INTERVAL_HOURS
    end

    def checkin_min_attempts
      AppDefaults::CHECKIN_MIN_ATTEMPTS
    end

    def checkin_min_attempt_interval_hours
      AppDefaults::CHECKIN_MIN_ATTEMPT_INTERVAL_HOURS
    end

    # Check-in maximum bounds
    def checkin_max_interval_hours
      AppDefaults::CHECKIN_MAX_INTERVAL_HOURS
    end

    def checkin_max_attempts
      AppDefaults::CHECKIN_MAX_ATTEMPTS
    end

    def checkin_max_attempt_interval_hours
      AppDefaults::CHECKIN_MAX_ATTEMPT_INTERVAL_HOURS
    end

    # Rate limiting
    def rate_limit_magic_link_per_ip
      AppDefaults::RATE_LIMIT_MAGIC_LINK_PER_IP
    end

    def rate_limit_magic_link_period
      AppDefaults::RATE_LIMIT_MAGIC_LINK_PERIOD
    end

    # Crypto (Argon2id parameters for client-side JS)
    def argon2id_ops_limit
      AppDefaults::ARGON2ID_OPS_LIMIT
    end

    def argon2id_mem_limit
      AppDefaults::ARGON2ID_MEM_LIMIT
    end

    # Returns KDF params as a hash for JSON serialization
    def kdf_params
      {
        opslimit: argon2id_ops_limit,
        memlimit: argon2id_mem_limit,
        algo: "argon2id13"
      }
    end

    # Invite tokens
    def invite_token_ttl_days
      AppDefaults::INVITE_TOKEN_TTL_DAYS
    end

    # Trusted contact
    def trusted_contact_default_pause_duration_hours
      AppDefaults::TRUSTED_CONTACT_DEFAULT_PAUSE_DURATION_HOURS
    end

    def trusted_contact_min_pause_duration_hours
      AppDefaults::TRUSTED_CONTACT_MIN_PAUSE_DURATION_HOURS
    end

    def trusted_contact_max_pause_duration_hours
      AppDefaults::TRUSTED_CONTACT_MAX_PAUSE_DURATION_HOURS
    end

    def trusted_contact_token_ttl_hours
      AppDefaults::TRUSTED_CONTACT_TOKEN_TTL_HOURS
    end
  end
end
