class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.integer :startgg_id
      t.string :name
      t.string :slug
      t.integer :num_entrants
      t.references :tournament, null: false, foreign_key: true

      t.timestamps
    end

    add_index :events, :startgg_id, unique: true
  end
end
