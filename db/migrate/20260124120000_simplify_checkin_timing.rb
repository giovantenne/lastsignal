# frozen_string_literal: true

class SimplifyCheckinTiming < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :checkin_attempts, :integer
    add_column :users, :checkin_attempt_interval_hours, :integer
    add_column :users, :checkin_attempts_sent, :integer, default: 0, null: false
    add_column :users, :last_checkin_attempt_at, :datetime

    remove_column :users, :grace_period_hours, :integer
    remove_column :users, :cooldown_period_hours, :integer
    remove_column :users, :delivery_delay_hours, :integer
    remove_column :users, :grace_started_at, :datetime
    remove_column :users, :cooldown_started_at, :datetime

    remove_index :users, name: "index_users_on_state_and_grace_started_at"
    remove_index :users, name: "index_users_on_state_and_cooldown_started_at"
  end
end
