class AddStartggTokensToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :startgg_access_token, :string
    add_column :users, :startgg_refresh_token, :string
    add_column :users, :startgg_token_expires_at, :datetime
  end
end
