# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliveryToken, type: :model do
  describe "validations" do
    subject { build(:delivery_token) }

    it { should validate_presence_of(:token_digest) }
    it { should validate_uniqueness_of(:token_digest) }
  end

  describe "associations" do
    it { should belong_to(:recipient) }
  end

  describe "scopes" do
    describe ".active" do
      it "includes non-revoked tokens" do
        token = create(:delivery_token)
        expect(DeliveryToken.active).to include(token)
      end

      it "excludes revoked tokens" do
        token = create(:delivery_token, :revoked)
        expect(DeliveryToken.active).not_to include(token)
      end
    end
  end

  describe ".generate_for" do
    let(:recipient) { create(:recipient) }

    it "creates a new token" do
      expect {
        DeliveryToken.generate_for(recipient)
      }.to change(DeliveryToken, :count).by(1)
    end

    it "returns the token and raw token" do
      token, raw_token = DeliveryToken.generate_for(recipient)
      expect(token).to be_a(DeliveryToken)
      expect(raw_token).to be_present
    end

    it "stores a digest, not the raw token" do
      token, raw_token = DeliveryToken.generate_for(recipient)
      expect(token.token_digest).not_to eq(raw_token)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(raw_token))
    end
  end

  describe ".find_by_token" do
    let(:recipient) { create(:recipient) }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let!(:token) { create(:delivery_token, recipient: recipient, raw_token: raw_token) }

    it "finds active token by raw token" do
      found = DeliveryToken.find_by_token(raw_token)
      expect(found).to eq(token)
    end

    it "returns nil for invalid token" do
      expect(DeliveryToken.find_by_token("invalid")).to be_nil
    end

    it "returns nil for blank token" do
      expect(DeliveryToken.find_by_token("")).to be_nil
      expect(DeliveryToken.find_by_token(nil)).to be_nil
    end

    it "returns nil for revoked token" do
      token.revoke!
      expect(DeliveryToken.find_by_token(raw_token)).to be_nil
    end
  end

  describe "#revoked?" do
    it "returns true when revoked_at is set" do
      token = build(:delivery_token, :revoked)
      expect(token.revoked?).to be true
    end

    it "returns false when revoked_at is nil" do
      token = build(:delivery_token, revoked_at: nil)
      expect(token.revoked?).to be false
    end
  end

  describe "#revoke!" do
    it "sets revoked_at timestamp" do
      token = create(:delivery_token)
      freeze_time do
        token.revoke!
        expect(token.revoked_at).to eq(Time.current)
      end
    end
  end

  describe "#record_access!" do
    it "sets last_accessed_at timestamp" do
      token = create(:delivery_token)
      freeze_time do
        token.record_access!
        expect(token.last_accessed_at).to eq(Time.current)
      end
    end
  end
end
