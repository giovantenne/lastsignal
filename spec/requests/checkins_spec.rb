# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Check-ins", type: :request do
  describe "GET /checkin/confirm/:token" do
    it "renders confirmation page without confirming" do
      raw_token = SecureRandom.urlsafe_base64(32)
      user = create(
        :user,
        checkin_token_digest: Digest::SHA256.hexdigest(raw_token),
        checkin_token_expires_at: 1.hour.from_now
      )

      get confirm_checkin_path(token: raw_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Confirm your check-in")
      expect(user.reload.last_checkin_confirmed_at).to be_nil
    end

    it "rejects invalid token" do
      get confirm_checkin_path(token: "invalid")

      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("Invalid or expired")
    end
  end

  describe "POST /checkin/confirm/:token" do
    it "confirms check-in and clears token" do
      raw_token = SecureRandom.urlsafe_base64(32)
      user = create(
        :user,
        checkin_token_digest: Digest::SHA256.hexdigest(raw_token),
        checkin_token_expires_at: 1.hour.from_now
      )

      post complete_checkin_path(token: raw_token)

      expect(response).to redirect_to(checkin_success_path)
      follow_redirect!
      expect(response.body).to include("Check-in confirmed")
      user.reload
      expect(user.last_checkin_confirmed_at).not_to be_nil
      expect(user.checkin_token_digest).to be_nil
    end
  end
end
