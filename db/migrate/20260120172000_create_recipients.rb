class CreateRecipients < ActiveRecord::Migration[8.0]
  def change
    create_table :recipients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :state, null: false, default: "invited"
      t.string :invite_token_digest
      t.datetime :invite_sent_at
      t.datetime :invite_expires_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :recipients, [ :user_id, :email ], unique: true
    add_index :recipients, :invite_token_digest, unique: true
    add_index :recipients, :state
  end
end
