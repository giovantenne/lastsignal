# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessCheckinsJob, type: :job do
  before do
    allow(AuditLog).to receive(:log)
  end
  describe "#perform" do
    it "processes all check-in phases" do
      job = ProcessCheckinsJob.new
      
      expect(job).to receive(:process_due_reminders)
      expect(job).to receive(:process_missed_checkins)
      expect(job).to receive(:process_grace_expirations)
      expect(job).to receive(:process_trusted_contact_pings)
      expect(job).to receive(:process_cooldown_expirations)
      
      job.perform
    end
  end

  describe "process_due_reminders" do
    let!(:user_due_soon) { create(:user).tap { |u| u.update_column(:next_checkin_at, 12.hours.from_now) } }
    let!(:user_due_later) { create(:user).tap { |u| u.update_column(:next_checkin_at, 3.days.from_now) } }
    let!(:user_overdue) { create(:user).tap { |u| u.update_column(:next_checkin_at, 2.hours.ago) } }

    it "sends a reminder for check-ins due within 24 hours" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :reminder).with(user_due_soon, anything)
      expect(user_due_soon.reload.checkin_reminder_sent_at).to be_present
    end

    it "does not send reminders for check-ins beyond 24 hours" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :reminder).with(user_due_later, anything)
    end

    it "does not send reminders for overdue check-ins" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :reminder).with(user_overdue, anything)
    end

    it "sends only one reminder per cycle" do
      ProcessCheckinsJob.new.perform

      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :reminder).with(user_due_soon, anything)
    end

    it "resets reminder after check-in confirmation" do
      ProcessCheckinsJob.new.perform
      user_due_soon.reload.confirm_checkin!

      expect(user_due_soon.reload.checkin_reminder_sent_at).to be_nil
    end
  end

  describe "process_missed_checkins" do
    let!(:user_needs_grace) { create(:user, :needs_checkin) }
    let!(:user_future_checkin) { create(:user, next_checkin_at: 1.week.from_now) }
    let!(:user_already_grace) { create(:user, :in_grace) }

    it "transitions users who missed check-in to grace" do
      ProcessCheckinsJob.new.perform
      
      expect(user_needs_grace.reload.state).to eq("grace")
    end

    it "does not transition users with future check-ins" do
      ProcessCheckinsJob.new.perform
      
      expect(user_future_checkin.reload.state).to eq("active")
    end

    it "sends grace period warning email" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :grace_period_warning).with(user_needs_grace, anything)
    end

    it "creates audit log" do
      expect(AuditLog).to receive(:log).with(hash_including(action: "state_to_grace")).at_least(:once)

      ProcessCheckinsJob.new.perform
    end
  end

  describe "process_grace_expirations" do
    let!(:user_grace_expired) { create(:user, :in_grace, grace_started_at: 4.days.ago, grace_period_hours: 72) }
    let!(:user_grace_active) { create(:user, :in_grace, grace_started_at: 1.hour.ago) }

    it "transitions users with expired grace to cooldown" do
      ProcessCheckinsJob.new.perform
      
      expect(user_grace_expired.reload.state).to eq("cooldown")
    end

    it "does not transition users still in grace" do
      ProcessCheckinsJob.new.perform
      
      expect(user_grace_active.reload.state).to eq("grace")
    end

    it "sends cooldown warning email with panic token" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :cooldown_warning)
    end

    it "generates panic token" do
      ProcessCheckinsJob.new.perform
      
      expect(user_grace_expired.reload.panic_token_digest).to be_present
    end

    it "creates audit log" do
      expect(AuditLog).to receive(:log).with(hash_including(action: "state_to_cooldown")).at_least(:once)

      ProcessCheckinsJob.new.perform
    end
  end

  describe "process_trusted_contact_pings" do
    let!(:user_in_grace) { create(:user, :in_grace) }
    let!(:user_active) { create(:user) }
    let!(:grace_contact) { create(:trusted_contact, user: user_in_grace) }
    let!(:active_contact) { create(:trusted_contact, user: user_active) }

    it "sends trusted contact pings during grace" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(TrustedContactMailer, :ping).with(grace_contact, anything)
    end

    it "sends user notice when pinging" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(TrustedContactMailer, :ping_notice).with(user_in_grace, grace_contact)
    end

    it "does not ping for active users" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(TrustedContactMailer, :ping).with(active_contact, anything)
    end

    it "creates audit log entry" do
      expect(AuditLog).to receive(:log).with(hash_including(action: "trusted_contact_ping_sent")).at_least(:once)

      ProcessCheckinsJob.new.perform
    end
  end

  describe "process_cooldown_expirations" do
    let!(:user_cooldown_expired) { create(:user, :in_cooldown, cooldown_started_at: 3.days.ago, cooldown_period_hours: 48) }
    let!(:user_cooldown_active) { create(:user, :in_cooldown, cooldown_started_at: 1.hour.ago) }

    it "transitions users with expired cooldown to delivered" do
      ProcessCheckinsJob.new.perform
      
      expect(user_cooldown_expired.reload.state).to eq("delivered")
    end

    it "does not transition users still in cooldown" do
      ProcessCheckinsJob.new.perform
      
      expect(user_cooldown_active.reload.state).to eq("cooldown")
    end

    it "does not deliver when trusted contact pause is active" do
      contact = create(:trusted_contact, user: user_cooldown_expired)
      contact.update!(paused_until: 2.days.from_now)

      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_job(DeliverMessagesJob)

      expect(user_cooldown_expired.reload.state).to eq("cooldown")
    end

    it "enqueues DeliverMessagesJob" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_job(DeliverMessagesJob).with(user_cooldown_expired.id)
    end

    it "creates audit log" do
      expect(AuditLog).to receive(:log).with(hash_including(action: "state_to_delivered")).at_least(:once)

      ProcessCheckinsJob.new.perform
    end

    it "sends delivery notice to user" do
      message = create(:message, :with_recipient, user: user_cooldown_expired)
      recipient_emails = message.recipients.pluck(:email)

      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :delivery_notice).with(user_cooldown_expired, recipient_emails)
    end

    it "progresses through the full timeline based on dates" do
      base_time = Time.current
      user = create(:user, :needs_checkin, checkin_interval_hours: 24, grace_period_hours: 24, cooldown_period_hours: 24)

      travel_to(base_time) do
        ProcessCheckinsJob.new.perform
        expect(user.reload.state).to eq("grace")
        expect(user.grace_started_at).to be_within(1.second).of(base_time)
      end

      travel_to(base_time + 25.hours) do
        ProcessCheckinsJob.new.perform
        expect(user.reload.state).to eq("cooldown")
        expect(user.cooldown_started_at).to be_within(1.second).of(base_time + 25.hours)
      end

      travel_to(base_time + 50.hours) do
        ProcessCheckinsJob.new.perform
        expect(user.reload.state).to eq("delivered")
        expect(user.delivered_at).to be_within(1.second).of(base_time + 50.hours)
      end
    end
  end
end
