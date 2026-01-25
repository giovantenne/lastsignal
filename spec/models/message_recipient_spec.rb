# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageRecipient, type: :model do
  describe "validations" do
    subject { build(:message_recipient) }

    it { should validate_presence_of(:encrypted_msg_key_b64u) }
    it { should validate_presence_of(:envelope_algo) }
    it { should validate_presence_of(:envelope_version) }
    it { should validate_numericality_of(:envelope_version).only_integer.is_greater_than(0) }

    describe "recipient_has_key validation" do
      it "requires recipient to have accepted and have a key" do
        recipient = create(:recipient, state: "invited")
        mr = build(:message_recipient, recipient: recipient)
        expect(mr).not_to be_valid
        expect(mr.errors[:recipient]).to include("must have accepted invite and registered a public key")
      end

      it "accepts recipient with key" do
        recipient = create(:recipient, :accepted)
        mr = build(:message_recipient, recipient: recipient)
        expect(mr).to be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to(:message) }
    it { should belong_to(:recipient) }
  end
end
