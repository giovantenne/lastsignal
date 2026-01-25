class RemoveTokenExpiresAtFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :checkin_token_expires_at, :datetime
    remove_column :users, :panic_token_expires_at, :datetime
  end
end
