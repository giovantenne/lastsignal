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

    it "disables Turbo for one-time secret generation forms" do
      user = create(:user)
      sign_in_as(user)

      get account_path

      document = Nokogiri::HTML.parse(response.body)

      generate_token_form = document.at_css("form[action='#{generate_external_checkin_token_account_path}']")
      recovery_code_form = document.at_css("form[action='#{regenerate_recovery_code_account_path}']")

      expect(generate_token_form).to be_present
      expect(generate_token_form["data-turbo"]).to eq("false")

      expect(recovery_code_form).to be_present
      expect(recovery_code_form["data-turbo"]).to eq("false")
    end

    it "points delivered users to the dashboard to delete their account" do
      user = create(:user, :delivered)
      sign_in_as(user)

      get account_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("delete it from the")
      expect(response.body).not_to include("Delete Account")
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

  describe "POST /account/reset_after_delivery" do
    let(:user) { create(:user, :delivered) }
    let(:recovery_code) { user.generate_recovery_code! }
    let(:recipient) { create(:recipient, :accepted, user: user) }
    let!(:delivery_token) { create(:delivery_token, recipient: recipient) }

    # Sign in first: login regenerates a not-yet-viewed recovery code.
    before do
      sign_in_as(user)
      recovery_code
    end

    it "requires authentication" do
      delete logout_path
      post reset_after_delivery_account_path, params: { recovery_code: recovery_code }
      expect(response).to redirect_to(login_path)
    end

    context "with a valid recovery code" do
      it "resets the account, revokes delivery links, logs and emails the user" do
        expect {
          post reset_after_delivery_account_path, params: { recovery_code: recovery_code }
        }.to change(AuditLog, :count).by(1)
          .and have_enqueued_mail(CheckinMailer, :reset_after_delivery_notice).with(user)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include("active again")
        expect(AuditLog.last.action).to eq("state_reset_after_delivery")

        user.reload
        expect(user.state).to eq("active")
        expect(user.delivered_at).to be_nil
        expect(user.next_checkin_at).to be > Time.current
        expect(delivery_token.reload).to be_revoked
      end

      it "makes the delivered dashboard card disappear" do
        get dashboard_path
        expect(response.body).to include("Account Is Read-Only")
        expect(response.body).to include(reset_after_delivery_account_path)

        post reset_after_delivery_account_path, params: { recovery_code: recovery_code }

        get dashboard_path
        expect(response.body).not_to include("Account Is Read-Only")
      end
    end

    context "with an invalid recovery code" do
      it "changes nothing and shows an alert" do
        expect {
          post reset_after_delivery_account_path, params: { recovery_code: "WRONG-CODE-0000-0000" }
        }.not_to change(AuditLog, :count)

        expect(user.reload.state).to eq("delivered")
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("Invalid recovery code")
        expect(delivery_token.reload).not_to be_revoked
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "changes nothing when the code is missing" do
        post reset_after_delivery_account_path
        expect(response).to redirect_to(dashboard_path)
        expect(user.reload.state).to eq("delivered")
      end
    end

    context "when the user is not delivered" do
      let(:user) { create(:user, :in_cooldown) }

      it "redirects with an alert and does not change state" do
        post reset_after_delivery_account_path, params: { recovery_code: recovery_code }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("not in delivered state")
        # Login counts as a check-in, so the user is active (not delivered) here.
        expect(user.reload.state).to eq("active")
        expect(delivery_token.reload).not_to be_revoked
      end
    end

    it "rate limits repeated attempts" do
      original_store = Rack::Attack.cache.store
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

      5.times do
        post reset_after_delivery_account_path, params: { recovery_code: "WRONG-CODE-0000-0000" }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post reset_after_delivery_account_path, params: { recovery_code: "WRONG-CODE-0000-0000" }

      expect(response).to have_http_status(:too_many_requests)
    ensure
      Rack::Attack.cache.store = original_store
    end
  end

  describe "DELETE /account" do
    context "when the user is not delivered" do
      it "deletes the account without a recovery code" do
        user = create(:user)
        sign_in_as(user)

        delete account_path

        expect(response).to redirect_to(login_path)
        expect(User.exists?(user.id)).to be false
      end
    end

    context "when the user is delivered" do
      let(:user) { create(:user, :delivered) }
      let(:recovery_code) { user.generate_recovery_code! }

      before do
        sign_in_as(user)
        recovery_code
      end

      it "deletes the account with a valid recovery code" do
        recipient = create(:recipient, :accepted, user: user)
        token = create(:delivery_token, recipient: recipient)

        delete account_path, params: { recovery_code: recovery_code }

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("deleted")
        expect(User.exists?(user.id)).to be false
        expect(DeliveryToken.exists?(token.id)).to be false
      end

      it "refuses to delete with an invalid recovery code" do
        delete account_path, params: { recovery_code: "WRONG-CODE-0000-0000" }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("Invalid recovery code")
        expect(User.exists?(user.id)).to be true
        expect(user.reload.state).to eq("delivered")
      end

      it "refuses to delete without a recovery code" do
        delete account_path

        expect(response).to redirect_to(dashboard_path)
        expect(User.exists?(user.id)).to be true
      end
    end
  end
end
