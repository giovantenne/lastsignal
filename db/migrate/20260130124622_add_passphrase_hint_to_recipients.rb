class AddPassphraseHintToRecipients < ActiveRecord::Migration[8.0]
  def change
    add_column :recipients, :passphrase_hint, :string, limit: 280
  end
end
