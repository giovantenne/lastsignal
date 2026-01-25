# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    state { "active" }
    checkin_interval_hours { 720 }  # 30 days
    checkin_attempts { 3 }
    checkin_attempt_interval_hours { 168 } # 7 days
    next_checkin_at { 1.week.from_now }

    trait :in_grace do
      state { "grace" }
      checkin_attempts_sent { 1 }
      last_checkin_attempt_at { 1.hour.ago }
    end

    trait :in_cooldown do
      state { "cooldown" }
      checkin_attempts_sent { 3 }
      last_checkin_attempt_at { 1.hour.ago }
      cooldown_warning_sent_at { 1.hour.ago }
    end

    trait :delivered do
      state { "delivered" }
      last_checkin_attempt_at { 3.days.ago }
      delivered_at { 1.hour.ago }
      next_checkin_at { nil }
    end

    trait :paused do
      state { "paused" }
      next_checkin_at { nil }
      last_checkin_attempt_at { nil }
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
    end
  end
end
