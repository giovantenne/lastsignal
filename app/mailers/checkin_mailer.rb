# frozen_string_literal: true

class CheckinMailer < ApplicationMailer
  def reminder(user, raw_token)
    @user = user
    @checkin_url = confirm_checkin_url(token: raw_token)
    @next_checkin_at = user.next_checkin_at
    @attempt_number = user.checkin_attempts_sent
    @attempt_total = user.effective_checkin_attempts
    @next_attempt_at = user.next_attempt_due_at
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Check-in reminder from #{@app_name}"
    )
  end

  def grace_period_warning(user, raw_token)
    @user = user
    @attempt_number = user.checkin_attempts_sent
    @attempt_total = user.effective_checkin_attempts
    @next_attempt_at = user.next_attempt_due_at
    @checkin_url = confirm_checkin_url(token: raw_token)
    @login_url = login_url
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Action required: You missed your #{@app_name} check-in"
    )
  end

  def cooldown_warning(user, raw_token)
    @user = user
    @checkin_url = confirm_checkin_url(token: raw_token)
    @attempt_number = user.checkin_attempts_sent
    @attempt_total = user.effective_checkin_attempts
    @delivery_due_at = user.delivery_due_at
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "URGENT: Your #{@app_name} messages will be delivered soon"
    )
  end

  def delivery_notice(user, recipient_emails)
    @user = user
    @delivered_at = user.delivered_at
    @recipient_emails = recipient_emails
    @app_name = AppConfig.smtp_from_name

    mail(
      to: user.email,
      subject: "Your #{@app_name} messages were delivered to recipients"
    )
  end
end
