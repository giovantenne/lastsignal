require "rails_helper"

RSpec.describe SendCheckinReminderJob, type: :job do
  before do
    allow(AuditLog).to receive(:log)
  end

  it "sends reminder when user has active messages" do
    user = create(:user)
    user.update_column(:next_checkin_at, 12.hours.from_now)
    create(:message, :with_recipient, user: user)

    expect {
      SendCheckinReminderJob.new.perform(user.id)
    }.to have_enqueued_mail(CheckinMailer, :reminder).with(user, anything)
  end

  it "skips reminder when user has no active messages" do
    user = create(:user)
    user.update_column(:next_checkin_at, 12.hours.from_now)

    expect {
      SendCheckinReminderJob.new.perform(user.id)
    }.not_to have_enqueued_mail(CheckinMailer, :reminder).with(user, anything)

    expect(user.reload.checkin_reminder_sent_at).to be_nil
  end
end
