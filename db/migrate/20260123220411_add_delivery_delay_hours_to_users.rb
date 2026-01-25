class AddDeliveryDelayHoursToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :delivery_delay_hours, :integer
  end
end
