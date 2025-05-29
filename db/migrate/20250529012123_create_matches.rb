class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.integer :startgg_id
      t.string :round
      t.integer :round_number
      t.string :identifier
      t.string :full_round_text
      t.string :display_score
      t.references :event, null: false, foreign_key: true
      t.integer :winner_id
      t.integer :loser_id

      t.timestamps
    end

    add_index :matches, :startgg_id, unique: true
  end
end
