class CreateUserEventParticipations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_event_participations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.integer :final_placement
      t.integer :entrant_id

      t.timestamps
    end
  end
end
