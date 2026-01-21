# frozen_string_literal: true

FactoryBot.define do
  factory :recipient_key do
    association :recipient
    public_key_b64u { Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false) }
    kdf_salt_b64u { Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false) }
    kdf_params do
      {
        "opslimit" => 3,
        "memlimit" => 268_435_456,
        "algo" => "argon2id13"
      }
    end
    key_version { 1 }
  end
end
