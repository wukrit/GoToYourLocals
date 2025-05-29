class AddSyncStatusColumnsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_sync_message, :text
    add_column :users, :last_sync_status, :string
  end
end
