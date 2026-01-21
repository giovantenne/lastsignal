class CreateEmailEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :email_events do |t|
      t.string :provider, null: false
      t.string :event_type, null: false
      t.string :message_id
      t.string :recipient_email_hash
      t.datetime :event_timestamp
      t.jsonb :raw_json, default: {}

      t.timestamps
    end

    add_index :email_events, :event_type
    add_index :email_events, :message_id
    add_index :email_events, :created_at
  end
end
