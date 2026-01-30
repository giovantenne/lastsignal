# frozen_string_literal: true

class TrustedContactMailer < ApplicationMailer
  def ping(contact, raw_token)
    @contact = contact
    @user = contact.user
    @confirm_url = trusted_contact_url(token: raw_token)
    @app_name = AppConfig.smtp_from_name

    mail(
      to: contact.email,
      subject: "Confirm #{@user.email} is safe"
    )
  end

  def ping_notice(user, contact)
    @user = user
    @contact = contact
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Trusted Contact ping sent"
    )
  end

  def confirmation_notice(user, contact)
    @user = user
    @contact = contact
    @paused_until = contact.paused_until
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Trusted Contact confirmed you're okay"
    )
  end
end
