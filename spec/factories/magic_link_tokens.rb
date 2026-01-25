# frozen_string_literal: true

FactoryBot.define do
  factory :magic_link_token do
    association :user
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    expires_at { 15.minutes.from_now }
    ip_hash { Digest::SHA256.hexdigest("127.0.0.1:secret")[0..15] }
    user_agent_hash { Digest::SHA256.hexdigest("TestAgent")[0..15] }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :used do
      used_at { 5.minutes.ago }
    end

    # Returns both the token record and the raw token for testing
    transient do
      raw_token { SecureRandom.urlsafe_base64(32) }
    end

    after(:build) do |token, evaluator|
      token.token_digest = Digest::SHA256.hexdigest(evaluator.raw_token)
    end
  end
end
