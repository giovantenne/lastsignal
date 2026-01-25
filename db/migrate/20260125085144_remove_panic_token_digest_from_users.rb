class RemovePanicTokenDigestFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :panic_token_digest, if_exists: true
    remove_column :users, :panic_token_digest, :string
  end
end
