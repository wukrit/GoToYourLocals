class RemoveUnusedDeviseFieldsFromUsers < ActiveRecord::Migration[8.0]
  def change
    # Columns for :database_authenticatable
    remove_column :users, :encrypted_password, :string

    # Columns for :recoverable
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime

    # Remove indexes associated with these columns
    # The index on email is still needed for finding users.
    remove_index :users, :reset_password_token, if_exists: true
  end
end
