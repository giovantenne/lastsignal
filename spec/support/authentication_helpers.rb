# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out
    session.delete(:user_id)
  end

  def current_user
    User.find_by(id: session[:user_id])
  end
end

# For request specs, we need to manipulate session differently
module RequestAuthenticationHelpers
  def sign_in_as(user)
    # Create a magic link token and verify it to establish session
    token, raw_token = MagicLinkToken.generate_for(user)
    get verify_magic_link_path(token: raw_token)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
  config.include RequestAuthenticationHelpers, type: :request
end
