# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliverMessagesJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user, :delivered) }

    context "when user is in delivered state" do
      let!(:recipient) { create(:recipient, :accepted, user: user) }
      let!(:message) { create(:message, user: user) }
      let!(:message_recipient) { create(:message_recipient, message: message, recipient: recipient) }

      it "generates delivery tokens for recipients" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.to change(DeliveryToken, :count).by(1)
      end

      it "sends delivery emails" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.to have_enqueued_mail(RecipientMailer, :delivery)
      end

      it "logs delivery emails" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.to change { AuditLog.where(action: "recipient_delivery_sent").count }.by(1)
      end

      it "includes message count in email" do
        expect(RecipientMailer).to receive(:delivery).with(recipient, anything, 1, []).and_call_original
        DeliverMessagesJob.new.perform(user.id)
      end
    end

    context "when user has multiple recipients with messages" do
      let!(:recipient1) { create(:recipient, :accepted, user: user) }
      let!(:recipient2) { create(:recipient, :accepted, user: user) }
      let!(:message1) { create(:message, user: user) }
      let!(:message2) { create(:message, user: user) }

      before do
        create(:message_recipient, message: message1, recipient: recipient1)
        create(:message_recipient, message: message2, recipient: recipient1)
        create(:message_recipient, message: message1, recipient: recipient2)
      end

      it "creates delivery tokens for each recipient" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.to change(DeliveryToken, :count).by(2)
      end

      it "sends emails to each recipient" do
        DeliverMessagesJob.new.perform(user.id)

        expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.twice
      end

      it "logs delivery emails for each recipient" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.to change { AuditLog.where(action: "recipient_delivery_sent").count }.by(2)
      end
    end

    context "when recipient has no messages" do
      let!(:recipient) { create(:recipient, :accepted, user: user) }

      it "does not send email to recipient without messages" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.not_to have_enqueued_mail(RecipientMailer, :delivery)
      end
    end

    context "when user is not in delivered state" do
      let(:active_user) { create(:user, state: "active") }

      it "does not send any emails" do
        expect {
          DeliverMessagesJob.new.perform(active_user.id)
        }.not_to have_enqueued_mail(RecipientMailer)
      end
    end

    context "when recipient is not accepted" do
      let!(:invited_recipient) { create(:recipient, state: "invited", user: user) }

      it "does not include invited recipients" do
        expect {
          DeliverMessagesJob.new.perform(user.id)
        }.not_to have_enqueued_mail(RecipientMailer, :delivery)
      end
    end
  end
end
