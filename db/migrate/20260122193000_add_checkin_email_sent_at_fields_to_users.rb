# frozen_string_literal: true

class AddCheckinEmailSentAtFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :grace_warning_sent_at, :datetime unless column_exists?(:users, :grace_warning_sent_at)
    add_column :users, :cooldown_warning_sent_at, :datetime unless column_exists?(:users, :cooldown_warning_sent_at)
    add_column :users, :delivery_notice_sent_at, :datetime unless column_exists?(:users, :delivery_notice_sent_at)
  end
end
