class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.integer :checkin_interval_hours
      t.integer :grace_period_hours
      t.integer :cooldown_period_hours
      t.string :state, null: false, default: "active"
      t.datetime :next_checkin_at
      t.datetime :last_checkin_confirmed_at
      t.datetime :grace_started_at
      t.datetime :cooldown_started_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :state
    add_index :users, :next_checkin_at
    add_index :users, [ :state, :next_checkin_at ]
    add_index :users, [ :state, :grace_started_at ]
    add_index :users, [ :state, :cooldown_started_at ]
  end
end
