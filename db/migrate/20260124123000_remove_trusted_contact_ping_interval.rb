# frozen_string_literal: true

class RemoveTrustedContactPingInterval < ActiveRecord::Migration[8.0]
  def change
    remove_column :trusted_contacts, :ping_interval_hours, :integer
  end
end
