# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessCheckinsJob, type: :job do
  before do
    allow(AuditLog).to receive(:log)
  end

  describe "#perform" do
    it "processes all phases" do
      job = ProcessCheckinsJob.new

      expect(job).to receive(:process_initial_attempts)
      expect(job).to receive(:process_delivery)
      expect(job).to receive(:process_followup_attempts)
      expect(job).to receive(:process_trusted_contact_pings)

      job.perform
    end
  end

  describe "initial attempts" do
    let!(:user_due) { create(:user).tap { |u| u.update_column(:next_checkin_at, 2.hours.ago) } }
    let!(:user_future) { create(:user).tap { |u| u.update_column(:next_checkin_at, 3.days.from_now) } }

    before do
      create(:message, :with_recipient, user: user_due)
      create(:message, :with_recipient, user: user_future)
    end

    it "sends a reminder for due check-ins and stays in active state" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :reminder).with(user_due, anything)

      expect(user_due.reload.state).to eq("active")
      expect(user_due.checkin_attempts_sent).to eq(1)
    end

    it "does not send reminders for future check-ins" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :reminder).with(user_future, anything)
    end
  end

  describe "followup attempts" do
    let!(:user_active_due) do
      # User in active state with 1 attempt already sent
      user = create(:user, state: :active, checkin_attempt_interval_hours: 24, last_checkin_attempt_at: 2.days.ago)
      user.update_column(:checkin_attempts_sent, 1)
      user
    end
    let!(:user_grace_due) do
      create(:user, :in_grace, checkin_attempt_interval_hours: 24, last_checkin_attempt_at: 2.days.ago)
    end
    let!(:user_grace_not_due) do
      create(:user, :in_grace, checkin_attempt_interval_hours: 24, last_checkin_attempt_at: 1.hour.ago)
    end

    before do
      create(:message, :with_recipient, user: user_active_due)
      create(:message, :with_recipient, user: user_grace_due)
      create(:message, :with_recipient, user: user_grace_not_due)
    end

    it "sends second reminder and transitions to grace" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :grace_period_warning).with(user_active_due, anything)

      user_active_due.reload
      expect(user_active_due.state).to eq("grace")
      expect(user_active_due.checkin_attempts_sent).to eq(2)
    end

    it "sends a followup reminder when due" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(CheckinMailer, :grace_period_warning).with(user_grace_due, anything)

      expect(user_grace_due.reload.checkin_attempts_sent).to eq(2)
    end

    it "does not send followup reminders before interval" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :grace_period_warning).with(user_grace_not_due, anything)
    end

    it "does not send more attempts after max is reached" do
      # User already at max attempts (3 of 3), still in cooldown
      user_max_attempts = create(
        :user,
        :in_cooldown,
        checkin_attempts: 3,
        checkin_attempt_interval_hours: 24,
        last_checkin_attempt_at: 2.days.ago,
        cooldown_warning_sent_at: 2.days.ago
      )
      user_max_attempts.update_column(:checkin_attempts_sent, 3)
      create(:message, :with_recipient, user: user_max_attempts)

      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(CheckinMailer, :cooldown_warning).with(user_max_attempts, anything)
    end
  end

  describe "delivery" do
    let!(:user_delivery_due) do
      create(
        :user,
        :in_cooldown,
        checkin_attempt_interval_hours: 24,
        last_checkin_attempt_at: 2.days.ago,
        cooldown_warning_sent_at: 2.days.ago
      )
    end
    let!(:user_delivery_not_due) do
      create(
        :user,
        :in_cooldown,
        checkin_attempt_interval_hours: 24,
        last_checkin_attempt_at: 1.hour.ago,
        cooldown_warning_sent_at: 1.hour.ago
      )
    end

    before do
      create(:message, :with_recipient, user: user_delivery_due)
      create(:message, :with_recipient, user: user_delivery_not_due)
    end

    it "delivers messages when due" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_job(DeliverMessagesJob).with(user_delivery_due.id)

      expect(user_delivery_due.reload.state).to eq("delivered")
    end

    it "does not deliver before interval" do
      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_job(DeliverMessagesJob).with(user_delivery_not_due.id)
    end
  end

  describe "trusted contact pings" do
    let!(:user_cooldown) { create(:user, :in_cooldown, cooldown_warning_sent_at: 1.hour.ago) }
    let!(:contact) { create(:trusted_contact, user: user_cooldown) }

    before do
      create(:message, :with_recipient, user: user_cooldown)
    end

    it "pings trusted contact after cooldown warning" do
      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(TrustedContactMailer, :ping).with(contact, anything)
    end

    it "pings trusted contact again after pause expires" do
      # Simulate: TC was pinged and confirmed, pause is now expired
      contact.update!(
        last_pinged_at: 20.days.ago,
        last_confirmed_at: 19.days.ago,
        paused_until: 4.days.ago  # Pause expired 4 days ago
      )

      expect {
        ProcessCheckinsJob.new.perform
      }.to have_enqueued_mail(TrustedContactMailer, :ping).with(contact, anything)

      # Should also reset cooldown_warning_sent_at to restart delivery timer
      expect(user_cooldown.reload.cooldown_warning_sent_at).to be_within(1.second).of(Time.current)
    end

    it "does not ping trusted contact while pause is active" do
      contact.update!(
        last_pinged_at: 5.days.ago,
        last_confirmed_at: 4.days.ago,
        paused_until: 10.days.from_now  # Pause still active
      )

      expect {
        ProcessCheckinsJob.new.perform
      }.not_to have_enqueued_mail(TrustedContactMailer, :ping).with(contact, anything)
    end
  end
end
