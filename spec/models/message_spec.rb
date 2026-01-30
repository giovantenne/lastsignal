# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  describe "validations" do
    it { should validate_presence_of(:ciphertext_b64u) }
    it { should validate_presence_of(:nonce_b64u) }
    it { should validate_presence_of(:aead_algo) }
    it { should validate_presence_of(:payload_version) }
    it { should validate_numericality_of(:payload_version).only_integer.is_greater_than(0) }
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:message_recipients).dependent(:destroy) }
    it { should have_many(:recipients).through(:message_recipients) }
  end

  describe "scopes" do
    describe ".with_recipients" do
      it "eager loads message_recipients and recipients" do
        message = create(:message, :with_recipient)

        # Should not trigger additional queries
        loaded = Message.with_recipients.find(message.id)
        expect(loaded.message_recipients).to be_loaded
      end
    end
  end

  describe ".create_encrypted" do
    let(:user) { create(:user) }
    let(:recipient) { create(:recipient, :accepted, user: user) }
    let(:ciphertext) { Base64.urlsafe_encode64(SecureRandom.random_bytes(64), padding: false) }
    let(:nonce) { Base64.urlsafe_encode64(SecureRandom.random_bytes(24), padding: false) }
    let(:encrypted_key) { Base64.urlsafe_encode64(SecureRandom.random_bytes(48), padding: false) }

    let(:recipient_envelopes) do
      [ {
        recipient_id: recipient.id,
        encrypted_msg_key_b64u: encrypted_key,
        envelope_algo: "crypto_box_seal",
        envelope_version: 1
      } ]
    end

    it "creates a message" do
      expect {
        Message.create_encrypted(
          user: user,
          label: "Test Message",
          ciphertext_b64u: ciphertext,
          nonce_b64u: nonce,
          recipient_envelopes: recipient_envelopes
        )
      }.to change(Message, :count).by(1)
    end

    it "creates message_recipients" do
      expect {
        Message.create_encrypted(
          user: user,
          label: "Test Message",
          ciphertext_b64u: ciphertext,
          nonce_b64u: nonce,
          recipient_envelopes: recipient_envelopes
        )
      }.to change(MessageRecipient, :count).by(1)
    end

    it "returns the created message" do
      message = Message.create_encrypted(
        user: user,
        label: "Test Message",
        ciphertext_b64u: ciphertext,
        nonce_b64u: nonce,
        recipient_envelopes: recipient_envelopes
      )

      expect(message).to be_a(Message)
      expect(message).to be_persisted
      expect(message.label).to eq("Test Message")
    end

    it "uses default algorithm values" do
      message = Message.create_encrypted(
        user: user,
        label: "Test",
        ciphertext_b64u: ciphertext,
        nonce_b64u: nonce,
        recipient_envelopes: recipient_envelopes
      )

      expect(message.aead_algo).to eq("xchacha20poly1305_ietf")
      expect(message.payload_version).to eq(1)
    end
  end

  describe "#update_encrypted" do
    let(:user) { create(:user) }
    let(:recipient1) { create(:recipient, :accepted, user: user) }
    let(:recipient2) { create(:recipient, :accepted, user: user) }
    let(:message) { create(:message, user: user) }

    before do
      create(:message_recipient, message: message, recipient: recipient1)
    end

    let(:new_ciphertext) { Base64.urlsafe_encode64(SecureRandom.random_bytes(64), padding: false) }
    let(:new_nonce) { Base64.urlsafe_encode64(SecureRandom.random_bytes(24), padding: false) }
    let(:encrypted_key) { Base64.urlsafe_encode64(SecureRandom.random_bytes(48), padding: false) }

    it "updates message content" do
      message.update_encrypted(
        label: "Updated Label",
        ciphertext_b64u: new_ciphertext,
        nonce_b64u: new_nonce,
        recipient_envelopes: [ {
          recipient_id: recipient2.id,
          encrypted_msg_key_b64u: encrypted_key
        } ]
      )

      message.reload
      expect(message.label).to eq("Updated Label")
      expect(message.ciphertext_b64u).to eq(new_ciphertext)
    end

    it "replaces recipients" do
      message.update_encrypted(
        label: "Updated",
        ciphertext_b64u: new_ciphertext,
        nonce_b64u: new_nonce,
        recipient_envelopes: [ {
          recipient_id: recipient2.id,
          encrypted_msg_key_b64u: encrypted_key
        } ]
      )

      expect(message.recipients).to contain_exactly(recipient2)
    end
  end

  describe "#delivery_payload_for" do
    let(:user) { create(:user) }
    let(:recipient) { create(:recipient, :accepted, user: user) }
    let(:message) { create(:message, user: user) }
    let!(:message_recipient) { create(:message_recipient, message: message, recipient: recipient) }

    it "returns payload hash for valid recipient" do
      payload = message.delivery_payload_for(recipient)

      expect(payload).to include(
        :ciphertext_b64u,
        :nonce_b64u,
        :aead_algo,
        :payload_version,
        :encrypted_msg_key_b64u,
        :envelope_algo,
        :kdf_salt_b64u,
        :kdf_params
      )
    end

    it "returns nil for non-recipient" do
      other_recipient = create(:recipient, :accepted)
      payload = message.delivery_payload_for(other_recipient)
      expect(payload).to be_nil
    end

    it "returns nil for recipient without key" do
      recipient_without_key = create(:recipient, user: user)
      payload = message.delivery_payload_for(recipient_without_key)
      expect(payload).to be_nil
    end
  end
end
