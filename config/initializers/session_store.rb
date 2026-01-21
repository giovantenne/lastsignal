# frozen_string_literal: true

# Session security configuration
# See: https://guides.rubyonrails.org/security.html#session-storage

Rails.application.configure do
  # Use cookie store with secure settings
  config.session_store :cookie_store,
    key: "_lastsignal_session",
    same_site: :lax,
    secure: Rails.env.production?,
    httponly: true,
    expire_after: 7.days
end
