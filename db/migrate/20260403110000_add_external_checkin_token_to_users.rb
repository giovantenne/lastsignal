# frozen_string_literal: true

class AddExternalCheckinTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :external_checkin_token_digest, :string
    add_column :users, :external_checkin_token_generated_at, :datetime
    add_column :users, :external_checkin_last_used_at, :datetime

    add_index :users, :external_checkin_token_digest, unique: true
  end
end
