# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recipient, type: :model do
  describe "validations" do
    subject { create(:recipient) }

    it { should validate_presence_of(:email) }
    it { should allow_value("recipient@example.com").for(:email) }
    it { should_not allow_value("invalid").for(:email) }
    it { should validate_uniqueness_of(:email).scoped_to(:user_id).case_insensitive }
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should have_one(:recipient_key).dependent(:destroy) }
    it { should have_many(:message_recipients).dependent(:destroy) }
    it { should have_many(:messages).through(:message_recipients) }
    it { should have_many(:delivery_tokens).dependent(:destroy) }
  end

  describe "enums" do
    it { should define_enum_for(:state).with_values(invited: "invited", accepted: "accepted").backed_by_column_of_type(:string) }
  end

  describe "callbacks" do
    describe "normalize_email" do
      it "downcases email" do
        recipient = create(:recipient, email: "RECIPIENT@EXAMPLE.COM")
        expect(recipient.email).to eq("recipient@example.com")
      end

      it "strips whitespace" do
        recipient = create(:recipient, email: "  recipient@example.com  ")
        expect(recipient.email).to eq("recipient@example.com")
      end
    end
  end

  describe "scopes" do
    describe ".with_keys" do
      it "includes accepted recipients with keys" do
        recipient = create(:recipient, :accepted)
        expect(Recipient.with_keys).to include(recipient)
      end

      it "excludes invited recipients" do
        recipient = create(:recipient, state: "invited")
        expect(Recipient.with_keys).not_to include(recipient)
      end
    end
  end

  describe "#generate_invite_token!" do
    let(:recipient) { create(:recipient) }

    it "returns raw token" do
      raw_token = recipient.generate_invite_token!
      expect(raw_token).to be_present
    end

    it "stores hashed token" do
      raw_token = recipient.generate_invite_token!
      expect(recipient.invite_token_digest).to eq(Digest::SHA256.hexdigest(raw_token))
    end

    it "sets invite_sent_at" do
      freeze_time do
        recipient.generate_invite_token!
        expect(recipient.invite_sent_at).to eq(Time.current)
      end
    end

    it "sets invite_expires_at" do
      recipient.generate_invite_token!
      expect(recipient.invite_expires_at).to be > Time.current
    end
  end

  describe ".find_by_invite_token" do
    let(:recipient) { create(:recipient) }
    let(:raw_token) { recipient.generate_invite_token! }

    it "finds recipient by raw token" do
      found = Recipient.find_by_invite_token(raw_token)
      expect(found).to eq(recipient)
    end

    it "returns nil for invalid token" do
      expect(Recipient.find_by_invite_token("invalid")).to be_nil
    end

    it "returns nil for blank token" do
      expect(Recipient.find_by_invite_token("")).to be_nil
      expect(Recipient.find_by_invite_token(nil)).to be_nil
    end
  end

  describe "#invite_valid?" do
    it "returns true for valid invite" do
      recipient = create(:recipient,
        state: "invited",
        invite_token_digest: "some-digest",
        invite_expires_at: 1.day.from_now)
      expect(recipient.invite_valid?).to be true
    end

    it "returns false if not invited state" do
      recipient = create(:recipient, :accepted)
      expect(recipient.invite_valid?).to be false
    end

    it "returns false if token expired" do
      recipient = create(:recipient, :expired_invite)
      expect(recipient.invite_valid?).to be false
    end

    it "returns false if no token" do
      recipient = build(:recipient, :accepted)  # accepted state has nil token
      recipient.state = "invited"  # Change back to invited to test the token check
      expect(recipient.invite_valid?).to be false
    end
  end

  describe "#accept!" do
    let(:recipient) { create(:recipient) }
    let(:public_key) { Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false) }
    let(:kdf_salt) { Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false) }
    let(:kdf_params) { { "opslimit" => 3, "memlimit" => 268_435_456, "algo" => "argon2id13" } }

    it "changes state to accepted" do
      recipient.accept!(public_key_b64u: public_key, kdf_salt_b64u: kdf_salt, kdf_params: kdf_params)
      expect(recipient.state).to eq("accepted")
    end

    it "creates recipient_key" do
      expect {
        recipient.accept!(public_key_b64u: public_key, kdf_salt_b64u: kdf_salt, kdf_params: kdf_params)
      }.to change { recipient.reload.recipient_key }.from(nil)

      expect(recipient.recipient_key.public_key_b64u).to eq(public_key)
    end

    it "sets accepted_at" do
      freeze_time do
        recipient.accept!(public_key_b64u: public_key, kdf_salt_b64u: kdf_salt, kdf_params: kdf_params)
        expect(recipient.accepted_at).to eq(Time.current)
      end
    end

    it "clears invite token" do
      recipient.accept!(public_key_b64u: public_key, kdf_salt_b64u: kdf_salt, kdf_params: kdf_params)
      expect(recipient.invite_token_digest).to be_nil
    end
  end

  describe "#can_receive_messages?" do
    it "returns true for accepted recipient with key" do
      recipient = create(:recipient, :accepted)
      expect(recipient.can_receive_messages?).to be true
    end

    it "returns false for invited recipient" do
      recipient = create(:recipient, state: "invited")
      expect(recipient.can_receive_messages?).to be false
    end
  end

  describe "#display_name" do
    it "returns name when present" do
      recipient = build(:recipient, name: "John Doe")
      expect(recipient.display_name).to eq("John Doe")
    end

    it "returns email when name is blank" do
      recipient = build(:recipient, name: nil, email: "john@example.com")
      expect(recipient.display_name).to eq("john@example.com")
    end

    it "returns email when name is empty string" do
      recipient = build(:recipient, name: "", email: "john@example.com")
      expect(recipient.display_name).to eq("john@example.com")
    end
  end
end
