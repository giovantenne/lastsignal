# frozen_string_literal: true

class AddCheckinReminderSentAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :checkin_reminder_sent_at, :datetime
  end
end
