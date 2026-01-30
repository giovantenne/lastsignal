# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecipientMailer, type: :mailer do
  describe "#invite" do
    let(:user) { create(:user, email: "sender@example.com") }
    let(:recipient) { create(:recipient, user: user, email: "recipient@example.com", name: "John Doe") }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let(:mail) { described_class.invite(recipient, raw_token) }

    it "sends to recipient email" do
      expect(mail.to).to eq([ "recipient@example.com" ])
    end

    it "includes sender email in subject" do
      expect(mail.subject).to include("sender@example.com")
    end

    it "includes invite URL with token" do
      expect(mail.body.encoded).to include(raw_token)
    end

    it "includes expiration info" do
      expect(mail.body.encoded).to include(AppConfig.invite_token_ttl_days.to_s)
    end
  end

  describe "#delivery" do
    let(:user) { create(:user, email: "sender@example.com") }
    let(:recipient) { create(:recipient, :accepted, user: user, email: "recipient@example.com") }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }

    context "with single message" do
      let(:mail) { described_class.delivery(recipient, raw_token, 1) }

      it "sends to recipient email" do
        expect(mail.to).to eq([ "recipient@example.com" ])
      end

      it "has singular subject" do
        expect(mail.subject).to include("1 message")
        expect(mail.subject).not_to include("messages")
      end

      it "includes delivery URL with token" do
        expect(mail.body.encoded).to include(raw_token)
      end
    end

    context "with multiple messages" do
      let(:mail) { described_class.delivery(recipient, raw_token, 3) }

      it "has plural subject" do
        expect(mail.subject).to include("3 messages")
      end
    end
  end

  describe "#accepted_notice" do
    let(:user) { create(:user, email: "sender@example.com") }
    let(:recipient) { create(:recipient, :accepted, user: user, email: "recipient@example.com", name: "John Doe") }
    let(:mail) { described_class.accepted_notice(recipient) }

    it "sends to sender email" do
      expect(mail.to).to eq([ "sender@example.com" ])
    end

    it "includes recipient name in subject" do
      expect(mail.subject).to include("John Doe")
    end

    it "includes login URL" do
      expect(mail.body.encoded).to include("login")
    end

    it "includes accepted timestamp" do
      expect(mail.body.encoded).to include("Accepted at")
    end
  end
end
