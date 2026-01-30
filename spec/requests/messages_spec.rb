# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:user) { create(:user) }
  let!(:recipient) { create(:recipient, :accepted, user: user) }

  before { sign_in_as(user) }

  describe "GET /messages" do
    it "lists user's messages" do
      message = create(:message, user: user, label: "Test Message")
      other_message = create(:message, label: "Other Message")

      get messages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Message")
      expect(response.body).not_to include("Other Message")
    end

    context "when not authenticated" do
      it "redirects to login" do
        delete logout_path
        get messages_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "GET /messages/new" do
    it "renders new message form" do
      get new_message_path
      expect(response).to have_http_status(:ok)
    end

    it "only shows recipients with keys" do
      invited_recipient = create(:recipient, user: user, state: "invited")

      get new_message_path

      expect(response.body).to include(recipient.email)
      expect(response.body).not_to include(invited_recipient.email)
    end
  end

  describe "POST /messages" do
    let(:ciphertext) { Base64.urlsafe_encode64(SecureRandom.random_bytes(64), padding: false) }
    let(:nonce) { Base64.urlsafe_encode64(SecureRandom.random_bytes(24), padding: false) }
    let(:encrypted_key) { Base64.urlsafe_encode64(SecureRandom.random_bytes(48), padding: false) }

    let(:valid_params) do
      {
        label: "My Secret Message",
        ciphertext_b64u: ciphertext,
        nonce_b64u: nonce,
        recipient_envelopes: [
          {
            recipient_id: recipient.id,
            encrypted_msg_key_b64u: encrypted_key
          }
        ].to_json
      }
    end

    context "with valid params" do
      it "creates a message" do
        expect {
          post messages_path, params: valid_params
        }.to change(Message, :count).by(1)
      end

      it "creates message recipient records" do
        expect {
          post messages_path, params: valid_params
        }.to change(MessageRecipient, :count).by(1)
      end

      it "creates audit log" do
        expect {
          post messages_path, params: valid_params
        }.to change { AuditLog.where(action: "message_created").count }.by(1)
      end

      it "returns JSON success response" do
        post messages_path, params: valid_params

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["redirect_url"]).to eq(messages_path)
      end

      it "resets check-in cycle when first active message is created" do
        user.update!(next_checkin_at: 2.months.ago, checkin_interval_hours: nil)

        travel_to(Time.current) do
          post messages_path, params: valid_params

          expect(user.reload.next_checkin_at).to be_within(1.second)
            .of(Time.current + AppConfig.checkin_default_interval_hours.hours)
          expect(user.reload.state).to eq("active")
        end

        expect(AuditLog.where(action: "checkin_resumed_for_messages", user: user).count).to eq(1)
      end
    end

    context "with invalid params" do
      it "returns error for missing ciphertext" do
        post messages_path, params: valid_params.except(:ciphertext_b64u)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /messages/:id" do
    let(:message) { create(:message, user: user) }

    it "shows the message" do
      get message_path(message)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(message.label)
    end

    it "cannot view other user's message" do
      other_message = create(:message)
      get message_path(other_message)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /messages/:id" do
    let!(:message) { create(:message, user: user) }

    it "deletes the message" do
      expect {
        delete message_path(message)
      }.to change(Message, :count).by(-1)
    end

    it "creates audit log" do
      expect {
        delete message_path(message)
      }.to change { AuditLog.where(action: "message_deleted").count }.by(1)
    end

    it "redirects to messages list" do
      delete message_path(message)
      expect(response).to redirect_to(messages_path)
    end
  end
end
