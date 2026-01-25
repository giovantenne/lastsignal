# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recipients", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "GET /recipients" do
    it "lists user's recipients" do
      recipient = create(:recipient, user: user)
      other_recipient = create(:recipient) # belongs to another user

      get recipients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(recipient.email)
      expect(response.body).not_to include(other_recipient.email)
    end

    context "when not authenticated" do
      it "redirects to login" do
        delete logout_path
        get recipients_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "GET /recipients/new" do
    it "renders new recipient form" do
      get new_recipient_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /recipients" do
    context "with valid params" do
      let(:valid_params) { { recipient: { email: "newrecipient@example.com", name: "John Doe" } } }

      it "creates a recipient" do
        expect {
          post recipients_path, params: valid_params
        }.to change(Recipient, :count).by(1)
      end

      it "sends invite email" do
        expect {
          post recipients_path, params: valid_params
        }.to have_enqueued_mail(RecipientMailer, :invite)
      end

      it "creates audit log" do
        expect {
          post recipients_path, params: valid_params
        }.to change(AuditLog, :count).by(2)
      end

      it "redirects to recipients list" do
        post recipients_path, params: valid_params
        expect(response).to redirect_to(recipients_path)
      end
    end

    context "with invalid params" do
      it "does not create recipient with invalid email" do
        expect {
          post recipients_path, params: { recipient: { email: "invalid", name: "Test" } }
        }.not_to change(Recipient, :count)
      end

      it "renders form with errors" do
        post recipients_path, params: { recipient: { email: "invalid" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with duplicate email for same user" do
      before { create(:recipient, user: user, email: "existing@example.com") }

      it "does not create duplicate" do
        expect {
          post recipients_path, params: { recipient: { email: "existing@example.com" } }
        }.not_to change(Recipient, :count)
      end
    end
  end

  describe "DELETE /recipients/:id" do
    let!(:recipient) { create(:recipient, user: user) }

    it "deletes the recipient" do
      expect {
        delete recipient_path(recipient)
      }.to change(Recipient, :count).by(-1)
    end

    it "redirects to recipients list" do
      delete recipient_path(recipient)
      expect(response).to redirect_to(recipients_path)
    end

    it "cannot delete other user's recipient" do
      other_recipient = create(:recipient)
      delete recipient_path(other_recipient)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /recipients/:id/resend_invite" do
    context "when recipient is invited" do
      let(:recipient) { create(:recipient, user: user, state: "invited") }

      it "resends invite email" do
        expect {
          post resend_invite_recipient_path(recipient)
        }.to have_enqueued_mail(RecipientMailer, :invite)
      end

      it "redirects to recipients list" do
        post resend_invite_recipient_path(recipient)
        expect(response).to redirect_to(recipients_path)
      end
    end

    context "when recipient has accepted" do
      let(:recipient) { create(:recipient, :accepted, user: user) }

      it "does not resend invite" do
        expect {
          post resend_invite_recipient_path(recipient)
        }.not_to have_enqueued_mail(RecipientMailer, :invite)
      end

      it "shows alert message" do
        post resend_invite_recipient_path(recipient)
        expect(flash[:alert]).to include("already accepted")
      end
    end
  end
end
