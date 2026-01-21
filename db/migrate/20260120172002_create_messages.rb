class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label
      t.text :ciphertext_b64u, null: false
      t.text :nonce_b64u, null: false
      t.string :aead_algo, null: false, default: "xchacha20poly1305_ietf"
      t.integer :payload_version, null: false, default: 1

      t.timestamps
    end

    add_index :messages, :created_at
  end
end
