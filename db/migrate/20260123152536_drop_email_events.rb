class DropEmailEvents < ActiveRecord::Migration[8.0]
  def change
    drop_table :email_events, if_exists: true
  end
end
