# frozen_string_literal: true

require "rails_helper"

RSpec.describe MagicLinkToken, type: :model do
  describe "validations" do
    subject { build(:magic_link_token) }

    it { should validate_presence_of(:token_digest) }
    it { should validate_uniqueness_of(:token_digest) }
    it { should validate_presence_of(:expires_at) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "scopes" do
    describe ".unused" do
      it "includes tokens without used_at" do
        token = create(:magic_link_token)
        expect(MagicLinkToken.unused).to include(token)
      end

      it "excludes used tokens" do
        token = create(:magic_link_token, :used)
        expect(MagicLinkToken.unused).not_to include(token)
      end
    end

    describe ".not_expired" do
      it "includes non-expired tokens" do
        token = create(:magic_link_token, expires_at: 1.hour.from_now)
        expect(MagicLinkToken.not_expired).to include(token)
      end

      it "excludes expired tokens" do
        token = create(:magic_link_token, :expired)
        expect(MagicLinkToken.not_expired).not_to include(token)
      end
    end

    describe ".valid_tokens" do
      it "includes unused, non-expired tokens" do
        token = create(:magic_link_token)
        expect(MagicLinkToken.valid_tokens).to include(token)
      end

      it "excludes used tokens" do
        token = create(:magic_link_token, :used)
        expect(MagicLinkToken.valid_tokens).not_to include(token)
      end

      it "excludes expired tokens" do
        token = create(:magic_link_token, :expired)
        expect(MagicLinkToken.valid_tokens).not_to include(token)
      end
    end
  end

  describe ".generate_for" do
    let(:user) { create(:user) }

    it "creates a new token" do
      expect {
        MagicLinkToken.generate_for(user)
      }.to change(MagicLinkToken, :count).by(1)
    end

    it "returns the token and raw token" do
      token, raw_token = MagicLinkToken.generate_for(user)
      expect(token).to be_a(MagicLinkToken)
      expect(raw_token).to be_present
    end

    it "stores a digest, not the raw token" do
      token, raw_token = MagicLinkToken.generate_for(user)
      expect(token.token_digest).not_to eq(raw_token)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(raw_token))
    end

    it "sets expiration time" do
      token, _ = MagicLinkToken.generate_for(user)
      expect(token.expires_at).to be > Time.current
    end

    context "with request" do
      let(:mock_request) { double(remote_ip: "192.168.1.1", user_agent: "TestBrowser/1.0") }

      it "stores hashed IP and user agent" do
        token, _ = MagicLinkToken.generate_for(user, request: mock_request)
        expect(token.ip_hash).to be_present
        expect(token.user_agent_hash).to be_present
      end
    end
  end

  describe ".find_and_verify" do
    let(:user) { create(:user) }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let!(:token) { create(:magic_link_token, user: user, raw_token: raw_token) }

    it "finds valid token by raw token" do
      found = MagicLinkToken.find_and_verify(raw_token)
      expect(found).to eq(token)
    end

    it "returns nil for invalid token" do
      found = MagicLinkToken.find_and_verify("invalid")
      expect(found).to be_nil
    end

    it "returns nil for blank token" do
      expect(MagicLinkToken.find_and_verify("")).to be_nil
      expect(MagicLinkToken.find_and_verify(nil)).to be_nil
    end

    it "returns nil for used token" do
      token.mark_used!
      found = MagicLinkToken.find_and_verify(raw_token)
      expect(found).to be_nil
    end

    it "returns nil for expired token" do
      token.update!(expires_at: 1.hour.ago)
      found = MagicLinkToken.find_and_verify(raw_token)
      expect(found).to be_nil
    end
  end

  describe "#mark_used!" do
    it "sets used_at timestamp" do
      token = create(:magic_link_token)
      freeze_time do
        token.mark_used!
        expect(token.used_at).to eq(Time.current)
      end
    end
  end

  describe "#used?" do
    it "returns true when used_at is set" do
      token = build(:magic_link_token, :used)
      expect(token.used?).to be true
    end

    it "returns false when used_at is nil" do
      token = build(:magic_link_token, used_at: nil)
      expect(token.used?).to be false
    end
  end

  describe "#expired?" do
    it "returns true when past expiration" do
      token = build(:magic_link_token, :expired)
      expect(token.expired?).to be true
    end

    it "returns false when before expiration" do
      token = build(:magic_link_token, expires_at: 1.hour.from_now)
      expect(token.expired?).to be false
    end
  end

  describe "#valid_token?" do
    it "returns true when unused and not expired" do
      token = build(:magic_link_token, used_at: nil, expires_at: 1.hour.from_now)
      expect(token.valid_token?).to be true
    end

    it "returns false when used" do
      token = build(:magic_link_token, :used)
      expect(token.valid_token?).to be false
    end

    it "returns false when expired" do
      token = build(:magic_link_token, :expired)
      expect(token.valid_token?).to be false
    end
  end

  describe ".cleanup_expired!" do
    it "deletes old expired tokens" do
      old_token = create(:magic_link_token, expires_at: 2.days.ago)
      new_token = create(:magic_link_token, expires_at: 1.hour.from_now)

      MagicLinkToken.cleanup_expired!

      expect(MagicLinkToken.exists?(old_token.id)).to be false
      expect(MagicLinkToken.exists?(new_token.id)).to be true
    end
  end
end
