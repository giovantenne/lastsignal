# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    state { "active" }
    checkin_interval_hours { 168 }  # 1 week
    grace_period_hours { 72 }       # 3 days
    cooldown_period_hours { 48 }    # 2 days
    next_checkin_at { 1.week.from_now }

    trait :in_grace do
      state { "grace" }
      grace_started_at { 1.hour.ago }
    end

    trait :in_cooldown do
      state { "cooldown" }
      grace_started_at { 4.days.ago }
      cooldown_started_at { 1.hour.ago }
    end

    trait :delivered do
      state { "delivered" }
      grace_started_at { 5.days.ago }
      cooldown_started_at { 3.days.ago }
      delivered_at { 1.hour.ago }
      next_checkin_at { nil }
    end

    trait :paused do
      state { "paused" }
      next_checkin_at { nil }
      grace_started_at { nil }
      cooldown_started_at { nil }
    end

    trait :needs_checkin do
      state { "active" }
      # Set to past time - use after(:create) to override the callback
      after(:create) do |user|
        user.update_column(:next_checkin_at, 1.hour.ago)
      end
    end

    trait :with_checkin_tokens do
      checkin_token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
      panic_token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
      checkin_token_expires_at { 1.hour.from_now }
      panic_token_expires_at { 1.hour.from_now }
    end
  end
end
