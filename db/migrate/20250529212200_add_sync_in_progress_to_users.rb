class AddSyncInProgressToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sync_in_progress, :boolean, default: false
  end
end
