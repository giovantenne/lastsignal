# frozen_string_literal: true

FactoryBot.define do
  factory :email_event do
    provider { "generic" }
    event_type { "delivered" }
    recipient_email_hash { Digest::SHA256.hexdigest("test@example.com")[0..15] }
    raw_json { { "status" => "delivered" } }

    trait :bounced do
      event_type { "bounced" }
    end

    trait :complained do
      event_type { "complained" }
    end

    trait :sendgrid do
      provider { "sendgrid" }
    end

    trait :postmark do
      provider { "postmark" }
    end
  end
end
