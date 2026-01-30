# frozen_string_literal: true

# Rate limiting configuration using Rack::Attack
# https://github.com/rack/rack-attack

class Rack::Attack
  # Use Redis for caching if available, otherwise use Rails cache
  Rack::Attack.cache.store = Rails.cache

  # ==========================================================================
  # Magic Link Rate Limiting (by IP and by Email)
  # ==========================================================================

  # Throttle magic link requests by IP
  throttle("magic_link/ip",
    limit: AppConfig.rate_limit_magic_link_per_ip,
    period: AppConfig.rate_limit_magic_link_period
  ) do |req|
    if req.path == "/auth/magic_link" && req.post?
      req.ip
    end
  end

  # Throttle magic link requests by email (prevents abuse with IP rotation)
  # Limit: 3 requests per email per hour
  throttle("magic_link/email", limit: 3, period: 3600) do |req|
    if req.path == "/auth/magic_link" && req.post?
      # Normalize email to prevent bypass via case/whitespace
      req.params["email"].to_s.downcase.strip.presence
    end
  end

  # Throttle magic link verification by IP
  throttle("magic_link_verify/ip", limit: 10, period: 60) do |req|
    if req.path.start_with?("/auth/verify") && req.get?
      req.ip
    end
  end

  # Throttle login page by IP
  throttle("login/ip", limit: 30, period: 60) do |req|
    if req.path == "/auth/login" && req.get?
      req.ip
    end
  end

  # Throttle invite accept by IP
  throttle("invite_accept/ip", limit: 10, period: 60) do |req|
    if req.path.start_with?("/invites/") && req.post?
      req.ip
    end
  end

  # Throttle invite view by IP
  throttle("invite_view/ip", limit: 30, period: 60) do |req|
    if req.path.start_with?("/invites/") && req.get?
      req.ip
    end
  end

  # Throttle delivery page by IP
  throttle("delivery/ip", limit: 30, period: 60) do |req|
    if req.path.start_with?("/delivery/") && req.get? && !req.path.end_with?("/payload")
      req.ip
    end
  end

  # Throttle delivery payload fetch by IP
  throttle("delivery_payload/ip", limit: 30, period: 60) do |req|
    if req.path.start_with?("/delivery/") && req.path.end_with?("/payload") && req.get?
      req.ip
    end
  end

  # Throttle trusted contact by IP
  throttle("trusted_contact/ip", limit: 10, period: 60) do |req|
    if req.path.start_with?("/trusted_contact/") && (req.get? || req.post?)
      req.ip
    end
  end

  # Throttle check-in confirm by IP
  throttle("checkin_confirm/ip", limit: 20, period: 60) do |req|
    if req.path.start_with?("/checkin/confirm/") && (req.get? || req.post?)
      req.ip
    end
  end

  # Throttle emergency stop by IP (strict - potential brute force target)
  throttle("emergency/ip", limit: 5, period: 300) do |req|
    if req.path == "/emergency" && req.post?
      req.ip
    end
  end

  # Throttle emergency stop by email (prevents brute force across IPs)
  # Limit: 5 attempts per email per hour
  throttle("emergency/email", limit: 5, period: 3600) do |req|
    if req.path == "/emergency" && req.post?
      req.params["email"].to_s.downcase.strip.presence
    end
  end

  # Throttle emergency stop form by IP
  throttle("emergency_form/ip", limit: 20, period: 60) do |req|
    if req.path == "/emergency" && req.get?
      req.ip
    end
  end

  # Block suspicious requests
  blocklist("block_bad_ips") do |req|
    # Add known bad IPs here if needed
    # Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.minute, bantime: 1.hour) do
    #   req.path == "/auth/magic_link" && req.post?
    # end
    false
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |req|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Rate limit exceeded. Please try again later." }.to_json ]
    ]
  end
end
