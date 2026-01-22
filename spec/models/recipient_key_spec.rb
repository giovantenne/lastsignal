# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecipientKey, type: :model do
  describe "validations" do
    subject { create(:recipient_key) }

    it { should validate_presence_of(:public_key_b64u) }
    it { should validate_presence_of(:kdf_salt_b64u) }
    it { should validate_presence_of(:kdf_params) }
    it { should validate_presence_of(:key_version) }
    it { should validate_numericality_of(:key_version).only_integer.is_greater_than(0) }
    it { should validate_uniqueness_of(:recipient_id) }

    describe "kdf_params validation" do
      it "requires opslimit key" do
        key = build(:recipient_key, kdf_params: { "memlimit" => 256, "algo" => "argon2id13" })
        expect(key).not_to be_valid
        expect(key.errors[:kdf_params]).to include("missing required keys: opslimit")
      end

      it "requires memlimit key" do
        key = build(:recipient_key, kdf_params: { "opslimit" => 3, "algo" => "argon2id13" })
        expect(key).not_to be_valid
        expect(key.errors[:kdf_params]).to include("missing required keys: memlimit")
      end

      it "requires algo key" do
        key = build(:recipient_key, kdf_params: { "opslimit" => 3, "memlimit" => 256 })
        expect(key).not_to be_valid
        expect(key.errors[:kdf_params]).to include("missing required keys: algo")
      end

      it "accepts valid kdf_params" do
        key = build(:recipient_key, kdf_params: { "opslimit" => 3, "memlimit" => 256, "algo" => "argon2id13" })
        expect(key).to be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to(:recipient) }
  end
end
