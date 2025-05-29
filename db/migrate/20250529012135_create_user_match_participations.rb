class CreateUserMatchParticipations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_match_participations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.boolean :is_winner

      t.timestamps
    end
  end
end
