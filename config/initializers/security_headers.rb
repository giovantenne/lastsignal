# frozen_string_literal: true

# Additional security headers for hardening
# These are applied in addition to Rails defaults

Rails.application.configure do
  config.action_dispatch.default_headers = {
    "X-Frame-Options" => "DENY",
    "X-Content-Type-Options" => "nosniff",
    "X-XSS-Protection" => "0", # Disabled as per modern best practices (CSP is better)
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "Permissions-Policy" => "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
  }
end
