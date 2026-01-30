class CreateMessageRecipients < ActiveRecord::Migration[8.0]
  def change
    create_table :message_recipients do |t|
      t.references :message, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: true
      t.text :encrypted_msg_key_b64u, null: false
      t.string :envelope_algo, null: false, default: "crypto_box_seal"
      t.integer :envelope_version, null: false, default: 1

      t.timestamps
    end

    add_index :message_recipients, [ :message_id, :recipient_id ], unique: true
  end
end
