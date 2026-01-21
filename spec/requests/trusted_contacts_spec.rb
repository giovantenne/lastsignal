# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trusted Contact", type: :request do
  describe "GET /trusted_contact/:token" do
    it "redirects for invalid token" do
      get trusted_contact_path(token: "invalid")

      expect(response).to redirect_to(login_path)
    end

    it "renders confirmation page for valid token" do
      contact = create(:trusted_contact)
      raw_token = contact.generate_token!

      get trusted_contact_path(token: raw_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Confirm status")
    end
  end

  describe "POST /trusted_contact/:token/confirm" do
    it "confirms and pauses delivery" do
      contact = create(:trusted_contact)
      raw_token = contact.generate_token!

      post trusted_contact_confirm_path(token: raw_token)

      expect(response).to have_http_status(:ok)
      expect(contact.reload.paused_until).to be_present
      expect(contact.token_digest).to be_nil
    end

    it "rejects expired token" do
      contact = create(:trusted_contact)
      raw_token = contact.generate_token!

      travel_to(AppConfig.trusted_contact_token_ttl_hours.hours.from_now + 1.hour) do
        post trusted_contact_confirm_path(token: raw_token)
      end

      expect(response).to redirect_to(login_path)
    end
  end
end
