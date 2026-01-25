# frozen_string_literal: true

class AuthMailer < ApplicationMailer
  def magic_link(user, raw_token)
    @user = user
    @magic_link_url = verify_magic_link_url(token: raw_token)
    @expires_in_minutes = AppConfig.magic_link_ttl_minutes
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Your #{@app_name} login link"
    )
  end
end
