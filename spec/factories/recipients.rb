# frozen_string_literal: true

FactoryBot.define do
  factory :recipient do
    association :user
    sequence(:email) { |n| "recipient#{n}@example.com" }
    name { Faker::Name.name }
    state { "invited" }
    invite_token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    invite_sent_at { Time.current }
    invite_expires_at { 7.days.from_now }

    trait :accepted do
      state { "accepted" }
      accepted_at { 1.day.ago }
      invite_token_digest { nil }

      after(:create) do |recipient|
        create(:recipient_key, recipient: recipient) unless recipient.recipient_key
      end
    end

    trait :expired_invite do
      invite_expires_at { 1.day.ago }
    end

    trait :without_name do
      name { nil }
    end

    # Returns the raw invite token for testing
    transient do
      raw_invite_token { SecureRandom.urlsafe_base64(32) }
    end

    after(:build) do |recipient, evaluator|
      if recipient.state == "invited" && recipient.invite_token_digest.nil?
        recipient.invite_token_digest = Digest::SHA256.hexdigest(evaluator.raw_invite_token)
      end
    end
  end
end
