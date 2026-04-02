# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts", type: :request do
  describe "GET /account" do
    it "disables caching for authenticated pages" do
      user = create(:user)
      sign_in_as(user)

      get account_path

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
    end
  end

  describe "POST /account/generate_external_checkin_token" do
    it "generates a token and logs the action" do
      user = create(:user)
      sign_in_as(user)

      expect {
        post generate_external_checkin_token_account_path
      }.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(AuditLog.last.action).to eq("external_checkin_token_generated")
      expect(response.headers["Cache-Control"]).to include("no-store")

      user.reload
      expect(user.external_checkin_token_digest).to be_present
      expect(user.external_checkin_token_generated_at).to be_present
      expect(response.body).to include("Copy this token now")
    end
  end

  describe "DELETE /account/revoke_external_checkin_token" do
    it "revokes the token and logs the action" do
      user = create(:user)
      user.generate_external_checkin_token!
      sign_in_as(user)

      expect {
        delete revoke_external_checkin_token_account_path
      }.to change(AuditLog, :count).by(1)

      expect(response).to redirect_to(account_path)
      expect(AuditLog.last.action).to eq("external_checkin_token_revoked")

      user.reload
      expect(user.external_checkin_token_digest).to be_nil
      expect(user.external_checkin_token_generated_at).to be_nil
      expect(user.external_checkin_last_used_at).to be_nil
    end
  end
end
