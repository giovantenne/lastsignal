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

      it "accepts the parameters configured on the server" do
        key = build(:recipient_key, kdf_params: AppConfig.kdf_params.stringify_keys)
        expect(key).to be_valid
      end

      it "accepts the configured parameters with symbol keys" do
        key = build(:recipient_key, kdf_params: AppConfig.kdf_params)
        expect(key).to be_valid
      end

      it "rejects parameters that are not an object" do
        key = build(:recipient_key, kdf_params: [ 3, 268_435_456, "argon2id13" ])
        expect(key).not_to be_valid
        expect(key.errors[:kdf_params]).to include("must be an object")
      end

      {
        "a weaker memlimit" => { "memlimit" => 8_192 },
        "a heavier memlimit" => { "memlimit" => 2**40 },
        "a weaker opslimit" => { "opslimit" => 1 },
        "a heavier opslimit" => { "opslimit" => 1_000_000 },
        "another algorithm" => { "algo" => "argon2i13" },
        "a numeric string" => { "opslimit" => "3" },
        "a float" => { "opslimit" => 3.0 },
        "a negative value" => { "memlimit" => -1 },
        "a null value" => { "memlimit" => nil },
        "an unexpected extra key" => { "extra" => "value" }
      }.each do |description, override|
        it "rejects #{description}" do
          key = build(:recipient_key, kdf_params: AppConfig.kdf_params.stringify_keys.merge(override))
          expect(key).not_to be_valid
          expect(key.errors[:kdf_params]).to include("do not match the server configuration")
        end
      end

      it "does not re-check parameters of a key that is already stored" do
        key = create(:recipient_key)
        key.update_columns(kdf_params: { "opslimit" => 2, "memlimit" => 67_108_864, "algo" => "argon2id13" })

        expect(key.reload).to be_valid
      end
    end

    describe "key material encoding" do
      def b64u(bytes)
        Base64.urlsafe_encode64(SecureRandom.random_bytes(bytes), padding: false)
      end

      it "accepts a 32-byte public key and a 16-byte salt" do
        expect(build(:recipient_key, public_key_b64u: b64u(32), kdf_salt_b64u: b64u(16))).to be_valid
      end

      it "rejects a public key of the wrong length" do
        key = build(:recipient_key, public_key_b64u: b64u(31))
        expect(key).not_to be_valid
        expect(key.errors[:public_key_b64u]).to be_present
      end

      it "rejects a public key that is not unpadded base64url" do
        [ "not base64!", Base64.strict_encode64("\xFF" * 32), "#{b64u(32)}=" ].each do |value|
          key = build(:recipient_key, public_key_b64u: value)
          expect(key).not_to be_valid, "expected #{value.inspect} to be rejected"
        end
      end

      it "rejects a salt of the wrong length" do
        [ b64u(8), b64u(32) ].each do |value|
          key = build(:recipient_key, kdf_salt_b64u: value)
          expect(key).not_to be_valid
          expect(key.errors[:kdf_salt_b64u]).to be_present
        end
      end
    end
  end

  describe "associations" do
    it { should belong_to(:recipient) }
  end
end
