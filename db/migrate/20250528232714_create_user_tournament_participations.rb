class CreateUserTournamentParticipations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_tournament_participations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true

      t.timestamps
    end
  end
end
