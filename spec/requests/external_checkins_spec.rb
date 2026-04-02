# frozen_string_literal: true

require "rails_helper"

RSpec.describe "External check-ins", type: :request do
  let(:json_response) { JSON.parse(response.body) }

  describe "POST /webhooks/keepalive" do
    it "accepts a valid token and resets the check-in cycle" do
      user = create(:user, :in_grace)
      raw_token = user.generate_external_checkin_token!

      freeze_time do
        expect {
          post external_keepalive_path, headers: { "Authorization" => "Bearer #{raw_token}" }
        }.to change(AuditLog, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response["status"]).to eq("ok")

        user.reload
        expect(user.state).to eq("active")
        expect(user.last_checkin_confirmed_at).to eq(Time.current)
        expect(user.external_checkin_last_used_at).to eq(Time.current)
        expect(AuditLog.last.action).to eq("external_checkin_received")
      end
    end

    it "rejects an invalid token and audits the attempt" do
      expect {
        post external_keepalive_path, headers: { "Authorization" => "Bearer invalid" }
      }.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Invalid external check-in token.")
      expect(AuditLog.last.action).to eq("external_checkin_token_invalid")
    end

    it "does not reactivate paused accounts" do
      user = create(:user, :paused)
      raw_token = user.generate_external_checkin_token!

      post external_keepalive_path, headers: { "Authorization" => "Bearer #{raw_token}" }

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]).to eq("External check-ins are unavailable in the current account state.")
      expect(user.reload.state).to eq("paused")
      expect(user.external_checkin_last_used_at).to be_nil
    end

    it "rate limits repeated requests" do
      original_store = Rack::Attack.cache.store
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

      user = create(:user)
      raw_token = user.generate_external_checkin_token!

      AppConfig.rate_limit_external_checkin_per_ip.times do
        post external_keepalive_path, headers: { "Authorization" => "Bearer #{raw_token}" }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post external_keepalive_path, headers: { "Authorization" => "Bearer #{raw_token}" }

      expect(response).to have_http_status(:too_many_requests)
    ensure
      Rack::Attack.cache.store = original_store
    end

    it "rate limits by token fingerprint across different IPs" do
      original_store = Rack::Attack.cache.store
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

      user = create(:user)
      raw_token = user.generate_external_checkin_token!

      AppConfig.rate_limit_external_checkin_per_token.times do |n|
        post external_keepalive_path,
          headers: { "Authorization" => "Bearer #{raw_token}" },
          env: { "REMOTE_ADDR" => "192.0.2.#{n}" }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post external_keepalive_path,
        headers: { "Authorization" => "Bearer #{raw_token}" },
        env: { "REMOTE_ADDR" => "198.51.100.10" }

      expect(response).to have_http_status(:too_many_requests)
    ensure
      Rack::Attack.cache.store = original_store
    end
  end
end
