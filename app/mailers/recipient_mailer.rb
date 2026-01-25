# frozen_string_literal: true

class RecipientMailer < ApplicationMailer
  def invite(recipient, raw_token)
    @recipient = recipient
    @sender = recipient.user
    @invite_url = accept_invite_url(token: raw_token)
    @expires_in_days = AppConfig.invite_token_ttl_days
    @app_name = AppConfig.smtp_from_name

    mail(
      to: recipient.email,
      subject: "#{@sender.email} has added you as a recipient on #{@app_name}"
    )
  end

  def delivery(recipient, raw_token, messages_count)
    @recipient = recipient
    @sender = recipient.user
    @delivery_url = delivery_url(token: raw_token)
    @messages_count = messages_count
    @app_name = AppConfig.smtp_from_name

    mail(
      to: recipient.email,
      subject: "You have #{messages_count} message#{'s' if messages_count > 1} waiting on #{@app_name}"
    )
  end

  # Notify the sender that a recipient has accepted their invite
  def accepted_notice(recipient)
    @recipient = recipient
    @sender = recipient.user
    @app_name = AppConfig.smtp_from_name
    @accepted_at = recipient.accepted_at

    mail(
      to: @sender.email,
      subject: "#{@recipient.display_name} accepted your invite on #{@app_name}"
    )
  end
end
