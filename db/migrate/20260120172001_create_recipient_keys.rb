class CreateRecipientKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :recipient_keys do |t|
      t.references :recipient, null: false, foreign_key: true, index: { unique: true }
      t.text :public_key_b64u, null: false
      t.text :kdf_salt_b64u, null: false
      t.jsonb :kdf_params, null: false, default: {}
      t.integer :key_version, null: false, default: 1

      t.timestamps
    end
  end
end
