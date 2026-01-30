# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  describe "validations" do
    it { should validate_presence_of(:actor_type) }
    it { should validate_presence_of(:action) }
    it { should validate_inclusion_of(:actor_type).in_array(AuditLog::ACTOR_TYPES) }
    it { should validate_inclusion_of(:action).in_array(AuditLog::ACTIONS) }
  end

  describe "associations" do
    it { should belong_to(:user).optional }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old = create(:audit_log, created_at: 1.day.ago)
        new = create(:audit_log, created_at: 1.hour.ago)

        expect(AuditLog.recent.first).to eq(new)
        expect(AuditLog.recent.last).to eq(old)
      end
    end

    describe ".for_action" do
      it "filters by action" do
        login = create(:audit_log, action: "login_success")
        logout = create(:audit_log, action: "logout")

        expect(AuditLog.for_action("login_success")).to include(login)
        expect(AuditLog.for_action("login_success")).not_to include(logout)
      end
    end
  end

  describe ".log" do
    let(:user) { create(:user) }

    it "creates an audit log entry" do
      expect {
        AuditLog.log(action: "login_success", user: user)
      }.to change(AuditLog, :count).by(1)
    end

    it "sets user and action" do
      log = AuditLog.log(action: "login_success", user: user)
      expect(log.user).to eq(user)
      expect(log.action).to eq("login_success")
    end

    it "defaults actor_type to user" do
      log = AuditLog.log(action: "login_success", user: user)
      expect(log.actor_type).to eq("user")
    end

    it "accepts custom actor_type" do
      log = AuditLog.log(action: "state_to_grace", actor_type: "system")
      expect(log.actor_type).to eq("system")
    end

    it "stores metadata" do
      log = AuditLog.log(action: "login_success", user: user, metadata: { ip: "127.0.0.1" })
      expect(log.metadata).to eq({ "ip" => "127.0.0.1" })
    end

    it "sanitizes sensitive metadata keys" do
      log = AuditLog.log(
        action: "login_success",
        user: user,
        metadata: { email: "test@example.com", password: "secret", api_token: "xyz" }
      )
      expect(log.metadata).to eq({ "email" => "test@example.com" })
      expect(log.metadata).not_to have_key("password")
      expect(log.metadata).not_to have_key("api_token")
    end

    context "with request" do
      let(:mock_request) { double(remote_ip: "192.168.1.1", user_agent: "TestBrowser/1.0") }

      it "stores hashed IP and user agent" do
        log = AuditLog.log(action: "login_success", user: user, request: mock_request)
        expect(log.ip_hash).to be_present
        expect(log.user_agent_hash).to be_present
      end
    end

    context "with invalid action" do
      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to create audit log/)
        result = AuditLog.log(action: "invalid_action", user: user)
        expect(result).to be_nil
      end
    end
  end
end
