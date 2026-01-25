class AddTokenExpirationsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :checkin_token_expires_at, :datetime
    add_column :users, :panic_token_expires_at, :datetime
  end
end
