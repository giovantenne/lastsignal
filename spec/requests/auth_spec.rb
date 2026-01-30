# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "GET /auth/login" do
    it "renders the login page" do
      get login_path
      expect(response).to have_http_status(:ok)
    end

    context "when allowlist is enabled" do
      before do
        ENV["ALLOWED_EMAILS"] = "allowed@example.com"
      end

      after do
        ENV["ALLOWED_EMAILS"] = ""
      end

      it "shows private instance notice" do
        get login_path

        expect(response.body).to include("Private instance: only allowlisted emails can sign in.")
        expect(response.body).not_to include("New here?")
      end
    end

    context "when allowlist is disabled" do
      before do
        ENV["ALLOWED_EMAILS"] = ""
      end

      it "shows new user message" do
        get login_path

        expect(response.body).to include("New here?")
        expect(response.body).not_to include("Private instance: only allowlisted emails can sign in.")
      end
    end

    context "when already authenticated" do
      let(:user) { create(:user) }

      it "redirects to dashboard" do
        sign_in_as(user)
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe "POST /auth/magic_link" do
    context "with valid email" do
      it "creates user if not exists" do
        expect {
          post magic_link_path, params: { email: "newuser@example.com" }
        }.to change(User, :count).by(1)
      end

      it "finds existing user" do
        user = create(:user, email: "existing@example.com")
        expect {
          post magic_link_path, params: { email: "existing@example.com" }
        }.not_to change(User, :count)
      end

      it "creates a magic link token" do
        expect {
          post magic_link_path, params: { email: "test@example.com" }
        }.to change(MagicLinkToken, :count).by(1)
      end

      it "enqueues email" do
        expect {
          post magic_link_path, params: { email: "test@example.com" }
        }.to have_enqueued_mail(AuthMailer, :magic_link)
      end

      it "creates audit log" do
        expect {
          post magic_link_path, params: { email: "test@example.com" }
        }.to change(AuditLog, :count).by(2)
      end

      it "redirects to login with notice" do
        post magic_link_path, params: { email: "test@example.com" }
        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("Check your email")
      end

      it "normalizes email case" do
        post magic_link_path, params: { email: "TEST@EXAMPLE.COM" }
        expect(User.last.email).to eq("test@example.com")
      end
    end

    context "with allowlist enabled" do
      before do
        ENV["ALLOWED_EMAILS"] = "allowed@example.com,owner@example.com"
      end

      after do
        ENV["ALLOWED_EMAILS"] = ""
      end

      it "blocks emails not on the list" do
        expect {
          post magic_link_path, params: { email: "blocked@example.com" }
        }.not_to change(User, :count)

        expect(MagicLinkToken.count).to eq(0)
        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("This instance is private")
      end

      it "allows emails on the list" do
        expect {
          post magic_link_path, params: { email: "allowed@example.com" }
        }.to change(User, :count).by(1)
      end

      it "blocks existing users not on the list" do
        create(:user, email: "blocked@example.com")

        expect {
          post magic_link_path, params: { email: "blocked@example.com" }
        }.not_to change(MagicLinkToken, :count)
      end
    end

    context "with invalid email" do
      it "does not create user" do
        expect {
          post magic_link_path, params: { email: "invalid" }
        }.not_to change(User, :count)
      end

      it "redirects with alert" do
        post magic_link_path, params: { email: "invalid" }
        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("valid email")
      end
    end

    context "with blank email" do
      it "does not create user" do
        expect {
          post magic_link_path, params: { email: "" }
        }.not_to change(User, :count)
      end
    end
  end

  describe "GET /auth/verify/:token" do
    let(:user) { create(:user) }
    let(:raw_token) { SecureRandom.urlsafe_base64(32) }
    let!(:token) { create(:magic_link_token, user: user, raw_token: raw_token) }

    context "with valid token" do
      it "signs in the user" do
        get verify_magic_link_path(token: raw_token)
        expect(session[:user_id]).to eq(user.id)
      end

      it "marks token as used" do
        get verify_magic_link_path(token: raw_token)
        expect(token.reload.used?).to be true
      end

      it "redirects to dashboard" do
        get verify_magic_link_path(token: raw_token)
        expect(response).to redirect_to(dashboard_path)
      end

      it "creates audit log" do
        expect {
          get verify_magic_link_path(token: raw_token)
        }.to change(AuditLog, :count).by(1)

        expect(AuditLog.last.action).to eq("login_success")
      end

      it "updates last_checkin_confirmed_at" do
        freeze_time do
          get verify_magic_link_path(token: raw_token)
          expect(user.reload.last_checkin_confirmed_at).to eq(Time.current)
        end
      end
    end

    context "with allowlist enabled" do
      before do
        ENV["ALLOWED_EMAILS"] = "allowed@example.com"
      end

      after do
        ENV["ALLOWED_EMAILS"] = ""
      end

      it "blocks users not on the list" do
        user.update!(email: "blocked@example.com")

        get verify_magic_link_path(token: raw_token)
        expect(session[:user_id]).to be_nil
        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("This instance is private")
      end

      it "allows users on the list" do
        user.update!(email: "allowed@example.com")

        get verify_magic_link_path(token: raw_token)
        expect(session[:user_id]).to eq(user.id)
      end
    end

    context "with invalid token" do
      it "does not sign in" do
        get verify_magic_link_path(token: "invalid")
        expect(session[:user_id]).to be_nil
      end

      it "redirects to login with alert" do
        get verify_magic_link_path(token: "invalid")
        expect(response).to redirect_to(login_path)
      end
    end

    context "with expired token" do
      let!(:token) { create(:magic_link_token, :expired, user: user, raw_token: raw_token) }

      it "does not sign in" do
        get verify_magic_link_path(token: raw_token)
        expect(session[:user_id]).to be_nil
      end
    end

    context "with used token" do
      let!(:token) { create(:magic_link_token, :used, user: user, raw_token: raw_token) }

      it "does not sign in" do
        get verify_magic_link_path(token: raw_token)
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe "DELETE /auth/logout" do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it "clears session" do
      delete logout_path
      expect(session[:user_id]).to be_nil
    end

    it "redirects to login" do
      delete logout_path
      expect(response).to redirect_to(login_path)
    end

    it "creates audit log" do
      expect {
        delete logout_path
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("logout")
    end
  end
end
