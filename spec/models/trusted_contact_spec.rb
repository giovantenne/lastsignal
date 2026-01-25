# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrustedContact, type: :model do
  describe ".find_by_token" do
    let(:contact) { create(:trusted_contact) }

    it "returns contact for valid token" do
      raw_token = contact.generate_token!

      expect(described_class.find_by_token(raw_token)).to eq(contact)
    end

    it "returns nil for expired token" do
      raw_token = contact.generate_token!

      travel_to(AppConfig.trusted_contact_token_ttl_hours.hours.from_now + 1.hour) do
        expect(described_class.find_by_token(raw_token)).to be_nil
      end
    end
  end

  describe "#confirm!" do
    let(:contact) { create(:trusted_contact) }

    it "sets paused_until and clears token" do
      contact.generate_token!

      expect {
        contact.confirm!
      }.to change(contact, :paused_until).and change(contact, :last_confirmed_at)

      expect(contact.token_digest).to be_nil
      expect(contact.token_expires_at).to be_nil
    end
  end

  describe "pause tracking" do
    let(:contact) { create(:trusted_contact) }

    it "marks pause active when paused_until in future" do
      contact.update!(paused_until: 2.hours.from_now)

      expect(contact.pause_active?).to be(true)
    end

    it "marks pause inactive when paused_until elapsed" do
      contact.update!(paused_until: 2.hours.ago)

      expect(contact.pause_active?).to be(false)
    end
  end
end
