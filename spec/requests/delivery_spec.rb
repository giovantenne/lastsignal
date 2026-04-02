# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Delivery", type: :request do
  let(:user) { create(:user, :delivered, delivered_at: Time.current) }
  let(:recipient) { create(:recipient, :accepted, user: user) }
  let!(:message) { create(:message, user: user, label: "Final note") }
  let!(:message_recipient) { create(:message_recipient, message: message, recipient: recipient) }
  let!(:delivery_token_record) { create(:delivery_token, recipient: recipient, raw_token: raw_token) }
  let(:raw_token) { SecureRandom.urlsafe_base64(32) }

  describe "GET /delivery/:token" do
    it "renders the delivery page and records access" do
      freeze_time do
        get delivery_path(token: raw_token)

        expect(response).to have_http_status(:ok)
        expect(response.headers["Cache-Control"]).to include("no-store")
        expect(response.body).to include("You Have Messages")
        expect(delivery_token_record.reload.last_accessed_at).to eq(Time.current)
      end
    end

    it "rejects invalid tokens" do
      get delivery_path(token: "invalid")

      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /delivery/:token/payload" do
    it "returns encrypted payloads and records access" do
      freeze_time do
        get delivery_payload_path(token: raw_token)

        expect(response).to have_http_status(:ok)
        expect(response.headers["Cache-Control"]).to include("no-store")

        body = JSON.parse(response.body)
        expect(body["sender_email"]).to eq(user.email)
        expect(body["messages"].size).to eq(1)
        expect(body["messages"].first["label"]).to eq("Final note")
        expect(delivery_token_record.reload.last_accessed_at).to eq(Time.current)
      end
    end

    it "rejects invalid tokens" do
      get delivery_payload_path(token: "invalid")

      expect(response).to have_http_status(:not_found)
    end
  end
end
