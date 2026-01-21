# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :user, factory: :user
    actor_type { "user" }
    action { "login_success" }
    metadata { {} }
    ip_hash { Digest::SHA256.hexdigest("127.0.0.1:secret")[0..15] }
    user_agent_hash { Digest::SHA256.hexdigest("TestAgent")[0..15] }

    trait :system_action do
      actor_type { "system" }
      user { nil }
    end

    trait :recipient_action do
      actor_type { "recipient" }
    end

    AuditLog::ACTIONS.each do |action_name|
      trait action_name.to_sym do
        action { action_name }
      end
    end
  end
end
