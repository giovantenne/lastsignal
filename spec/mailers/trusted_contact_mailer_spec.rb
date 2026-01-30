# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrustedContactMailer, type: :mailer do
  describe "#ping" do
    let(:contact) { create(:trusted_contact, email: "trusted@example.com") }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let(:mail) { described_class.ping(contact, raw_token) }

    it "sends to trusted contact email" do
      expect(mail.to).to eq([ "trusted@example.com" ])
    end

    it "includes confirmation URL" do
      expect(mail.body.encoded).to include(raw_token)
    end
  end

  describe "#ping_notice" do
    let(:contact) { create(:trusted_contact) }
    let(:mail) { described_class.ping_notice(contact.user, contact) }

    it "sends to user email" do
      expect(mail.to).to eq([ contact.user.email ])
    end
  end

  describe "#confirmation_notice" do
    let(:contact) { create(:trusted_contact, paused_until: 2.days.from_now) }
    let(:mail) { described_class.confirmation_notice(contact.user, contact) }

    it "sends to user email" do
      expect(mail.to).to eq([ contact.user.email ])
    end

    it "includes pause time" do
      expect(mail.body.encoded).to include(contact.paused_until.strftime("%B %d, %Y"))
    end
  end
end
