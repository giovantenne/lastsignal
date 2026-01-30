# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthMailer, type: :mailer do
  describe "#magic_link" do
    let(:user) { create(:user, email: "test@example.com") }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let(:mail) { described_class.magic_link(user, raw_token) }

    it "sends to user email" do
      expect(mail.to).to eq([ "test@example.com" ])
    end

    it "has appropriate subject" do
      expect(mail.subject).to include("login link")
    end

    it "includes magic link URL in body" do
      expect(mail.body.encoded).to include(raw_token)
    end

    it "includes expiration time" do
      expect(mail.body.encoded).to include(AppConfig.magic_link_ttl_minutes.to_s)
    end

    it "renders both HTML and text templates" do
      expect(mail.body.parts.map(&:content_type)).to include(
        "text/plain; charset=UTF-8",
        "text/html; charset=UTF-8"
      )
    end
  end
end
