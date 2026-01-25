# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { "#{AppConfig.smtp_from_name} <#{AppConfig.smtp_from_email}>" }
  layout "mailer"
end
