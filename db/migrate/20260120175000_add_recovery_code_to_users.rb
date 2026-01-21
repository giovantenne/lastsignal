# frozen_string_literal: true

class AddRecoveryCodeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :recovery_code_digest, :string
    add_column :users, :recovery_code_viewed_at, :datetime
  end
end
