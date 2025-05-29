class CreateTournaments < ActiveRecord::Migration[8.0]
  def change
    create_table :tournaments do |t|
      t.string :name
      t.string :slug
      t.datetime :start_at
      t.datetime :end_at
      t.boolean :is_online
      t.string :venue_name
      t.string :city
      t.string :state
      t.string :country_code
      t.bigint :startgg_id
      t.json :images

      t.timestamps
    end
    add_index :tournaments, :startgg_id, unique: true
  end
end
