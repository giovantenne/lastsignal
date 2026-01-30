# frozen_string_literal: true

FactoryBot.define do
  factory :message_recipient do
    association :message
    association :recipient, factory: [ :recipient, :accepted ]
    encrypted_msg_key_b64u { Base64.urlsafe_encode64(SecureRandom.random_bytes(48), padding: false) }
    envelope_algo { "crypto_box_seal" }
    envelope_version { 1 }
  end
end
