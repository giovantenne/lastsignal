# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailEvent, type: :model do
  describe "validations" do
    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:event_type) }
    it { should validate_inclusion_of(:provider).in_array(EmailEvent::PROVIDERS) }
    it { should validate_inclusion_of(:event_type).in_array(EmailEvent::EVENT_TYPES) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old = create(:email_event, created_at: 1.day.ago)
        new = create(:email_event, created_at: 1.hour.ago)
        
        expect(EmailEvent.recent.first).to eq(new)
        expect(EmailEvent.recent.last).to eq(old)
      end
    end

    describe ".bounces" do
      it "returns only bounced events" do
        bounce = create(:email_event, :bounced)
        delivered = create(:email_event, event_type: "delivered")
        
        expect(EmailEvent.bounces).to include(bounce)
        expect(EmailEvent.bounces).not_to include(delivered)
      end
    end

    describe ".complaints" do
      it "returns only complained events" do
        complaint = create(:email_event, :complained)
        delivered = create(:email_event, event_type: "delivered")
        
        expect(EmailEvent.complaints).to include(complaint)
        expect(EmailEvent.complaints).not_to include(delivered)
      end
    end
  end

  describe "constants" do
    it "defines valid providers" do
      expect(EmailEvent::PROVIDERS).to include("sendgrid", "postmark", "mailgun", "ses", "generic")
    end

    it "defines valid event types" do
      expect(EmailEvent::EVENT_TYPES).to include("delivered", "bounced", "complained", "opened", "clicked", "deferred")
    end
  end
end
