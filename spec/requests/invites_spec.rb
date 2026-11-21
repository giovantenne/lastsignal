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

    it "rejects malformed kdf params" do
      post accept_invite_path(token: raw_token), params: valid_params.merge(kdf_params: "{invalid")

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid key derivation parameters.")
    end

    it "accepts the JSON body sent by the invite page" do
      post accept_invite_path(token: raw_token),
           params: valid_params.merge(kdf_params: AppConfig.kdf_params),
           as: :json

      expect(response).to have_http_status(:success)
      expect(recipient.reload.recipient_key.kdf_params).to eq(AppConfig.kdf_params.stringify_keys)
    end

    it "rejects kdf params that are not an object" do
      [ "[3, 268435456]", "3", '"argon2id13"' ].each do |value|
        post accept_invite_path(token: raw_token), params: valid_params.merge(kdf_params: value)

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid key derivation parameters.")
      end

      expect(recipient.reload.state).to eq("invited")
    end

    it "rejects kdf params that differ from the server configuration" do
      [
        { opslimit: 1, memlimit: 8_192, algo: "argon2id13" },
        { opslimit: 3, memlimit: 2**40, algo: "argon2id13" },
        { opslimit: 3, memlimit: 268_435_456, algo: "argon2i13" },
        { opslimit: "3", memlimit: 268_435_456, algo: "argon2id13" }
      ].each do |kdf_params|
        post accept_invite_path(token: raw_token),
             params: valid_params.merge(kdf_params: kdf_params),
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to include("do not match the server configuration")
      end

      recipient.reload
      expect(recipient.state).to eq("invited")
      expect(recipient.recipient_key).to be_nil
      expect(recipient.invite_valid?).to be(true)
    end

    it "rejects a public key or salt of the wrong size" do
      short = Base64.urlsafe_encode64(SecureRandom.random_bytes(8), padding: false)

      post accept_invite_path(token: raw_token), params: valid_params.merge(public_key_b64u: short)
      expect(response).to have_http_status(:unprocessable_content)

      post accept_invite_path(token: raw_token), params: valid_params.merge(kdf_salt_b64u: "not base64!")
      expect(response).to have_http_status(:unprocessable_content)

      expect(recipient.reload.state).to eq("invited")
    end
  end

  describe "GET /invites/:token" do
    let(:user) { create(:user) }
    let(:recipient) { create(:recipient, user: user) }
    let!(:raw_token) { recipient.generate_invite_token! }

    it "shows invite page for valid token" do
      get accept_invite_path(token: raw_token)

      expect(response).to have_http_status(:success)
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "redirects for invalid token" do
      get accept_invite_path(token: "invalid")

      expect(response).to redirect_to(login_path)
    end
  end
end
