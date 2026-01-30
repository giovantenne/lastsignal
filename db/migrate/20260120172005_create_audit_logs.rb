class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :actor_type, null: false
      t.string :action, null: false
      t.json :metadata, default: {}
      t.string :ip_hash
      t.string :user_agent_hash

      t.timestamps
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :user_id, :created_at ]
  end
end
