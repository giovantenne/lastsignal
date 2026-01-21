# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :user
    label { Faker::Lorem.sentence(word_count: 3) }
    ciphertext_b64u { Base64.urlsafe_encode64(SecureRandom.random_bytes(64), padding: false) }
    nonce_b64u { Base64.urlsafe_encode64(SecureRandom.random_bytes(24), padding: false) }
    aead_algo { "xchacha20poly1305_ietf" }
    payload_version { 1 }

    trait :with_recipient do
      after(:create) do |message|
        recipient = create(:recipient, :accepted, user: message.user)
        create(:message_recipient, message: message, recipient: recipient)
      end
    end
  end
end
