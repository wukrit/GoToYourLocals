class AddTagToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :tag, :string
  end
end
