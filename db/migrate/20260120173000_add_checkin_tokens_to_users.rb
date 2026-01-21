class AddCheckinTokensToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :checkin_token_digest, :string
    add_column :users, :panic_token_digest, :string

    add_index :users, :checkin_token_digest, unique: true
    add_index :users, :panic_token_digest, unique: true
  end
end
