# frozen_string_literal: true

FactoryBot.define do
  factory :delivery_token do
    association :recipient
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :accessed do
      last_accessed_at { 30.minutes.ago }
    end

    transient do
      raw_token { SecureRandom.urlsafe_base64(32) }
    end

    after(:build) do |token, evaluator|
      token.token_digest = Digest::SHA256.hexdigest(evaluator.raw_token)
    end
  end
end
