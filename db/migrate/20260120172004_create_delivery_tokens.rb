class CreateDeliveryTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_tokens do |t|
      t.references :recipient, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :revoked_at
      t.datetime :last_accessed_at

      t.timestamps
    end

    add_index :delivery_tokens, :token_digest, unique: true
    add_index :delivery_tokens, [ :recipient_id, :created_at ]
  end
end
