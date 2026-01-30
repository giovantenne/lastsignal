class CreateMagicLinkTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_link_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :ip_hash
      t.string :user_agent_hash

      t.timestamps
    end

    add_index :magic_link_tokens, :token_digest, unique: true
    add_index :magic_link_tokens, :expires_at
    add_index :magic_link_tokens, [ :user_id, :created_at ]
  end
end
