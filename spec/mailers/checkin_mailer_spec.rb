# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckinMailer, type: :mailer do
  describe "#reminder" do
    let(:user) { create(:user, email: "test@example.com", next_checkin_at: 1.day.from_now) }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let(:mail) { described_class.reminder(user, raw_token) }

    it "sends to user email" do
      expect(mail.to).to eq(["test@example.com"])
    end

    it "has appropriate subject" do
      expect(mail.subject).to include("Check-in reminder")
    end

    it "includes check-in URL with token" do
      expect(mail.body.encoded).to include(raw_token)
    end
  end

  describe "#grace_period_warning" do
    let(:user) { create(:user, :in_grace, email: "test@example.com") }
    let(:mail) { described_class.grace_period_warning(user) }

    it "sends to user email" do
      expect(mail.to).to eq(["test@example.com"])
    end

    it "has urgent subject" do
      expect(mail.subject).to include("missed your")
    end

    it "includes login URL" do
      expect(mail.body.encoded).to include("login")
    end
  end

  describe "#cooldown_warning" do
    let(:user) { create(:user, :in_cooldown, email: "test@example.com") }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let(:mail) { described_class.cooldown_warning(user, raw_token) }

    it "sends to user email" do
      expect(mail.to).to eq(["test@example.com"])
    end

    it "has urgent subject" do
      expect(mail.subject).to include("URGENT")
    end

    it "includes panic revoke URL with token" do
      expect(mail.body.encoded).to include(raw_token)
    end
  end
end
