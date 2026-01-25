# frozen_string_literal: true

class CreateTrustedContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :trusted_contacts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :email, null: false
      t.string :name
      t.string :token_digest
      t.datetime :token_expires_at
      t.integer :ping_interval_hours
      t.integer :pause_duration_hours
      t.datetime :last_pinged_at
      t.datetime :last_confirmed_at
      t.datetime :paused_until

      t.timestamps
    end

    add_index :trusted_contacts, :token_digest, unique: true
  end
end
