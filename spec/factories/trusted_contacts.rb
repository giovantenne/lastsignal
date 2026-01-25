# frozen_string_literal: true

FactoryBot.define do
  factory :trusted_contact do
    association :user
    sequence(:email) { |n| "trusted#{n}@example.com" }
    name { "Trusted Contact" }
    pause_duration_hours { 168 }
  end
end
