# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invites", type: :request do
  describe "POST /invites/:token" do
    let(:user) { create(:user) }
    let(:recipient) { create(:recipient, user: user) }
    let!(:raw_token) { recipient.generate_invite_token! }

    let(:valid_params) do
      {
        public_key_b64u: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
        kdf_salt_b64u: Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false),
        kdf_params: { opslimit: 3, memlimit: 268_435_456, algo: "argon2id13" }.to_json
      }
    end

    it "sends accepted notice email to sender" do
      expect {
        post accept_invite_path(token: raw_token), params: valid_params
      }.to have_enqueued_mail(RecipientMailer, :accepted_notice).with(recipient)

      expect(response).to have_http_status(:success)
    end

    it "accepts the invite and updates recipient state" do
      post accept_invite_path(token: raw_token), params: valid_params

      expect(response).to have_http_status(:success)
      expect(recipient.reload.state).to eq("accepted")
    end

    it "rejects invalid token" do
      post accept_invite_path(token: "invalid"), params: valid_params

      expect(response).to have_http_status(:not_found)
    end

    it "rejects expired invite" do
      recipient.update!(invite_expires_at: 1.day.ago)

      post accept_invite_path(token: raw_token), params: valid_params

      expect(response).to have_http_status(:gone)
    end
  end

  describe "GET /invites/:token" do
    let(:user) { create(:user) }
    let(:recipient) { create(:recipient, user: user) }
    let!(:raw_token) { recipient.generate_invite_token! }

    it "shows invite page for valid token" do
      get accept_invite_path(token: raw_token)

      expect(response).to have_http_status(:success)
    end

    it "redirects for invalid token" do
      get accept_invite_path(token: "invalid")

      expect(response).to redirect_to(login_path)
    end
  end
end
