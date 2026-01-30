# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none

    # Allow libsodium from CDN for client-side crypto
    # wasm-unsafe-eval is needed for WebAssembly (libsodium)
    # strict-dynamic allows scripts loaded by trusted scripts
    if Rails.env.development?
      policy.script_src :self, "https://cdn.jsdelivr.net", :wasm_unsafe_eval, :unsafe_inline, :unsafe_eval
    else
      policy.script_src :self, "https://cdn.jsdelivr.net", :wasm_unsafe_eval, :strict_dynamic
    end

    policy.style_src :self, :unsafe_inline # Tailwind requires inline styles
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self

    # Connect to self for API calls, and jsdelivr for libsodium source maps
    policy.connect_src :self, "https://cdn.jsdelivr.net"

    # Uncomment to report CSP violations (useful for debugging)
    # policy.report_uri "/csp-violation-report"
  end

  # Generate nonces for permitted importmap, inline scripts, and inline styles.
  # Only use nonces in production - in development we use unsafe-inline
  unless Rails.env.development?
    config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[script-src]
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = AppDefaults::CSP_REPORT_ONLY
end
