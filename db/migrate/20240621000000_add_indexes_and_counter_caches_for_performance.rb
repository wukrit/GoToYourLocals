class AddIndexesAndCounterCachesForPerformance < ActiveRecord::Migration[7.0]
  def change
    # Add indexes for foreign key relationships to improve query performance
    reversible do |dir|
      dir.up do
        # Check if indexes exist before adding them
        unless index_exists?(:events, :tournament_id)
          add_index :events, :tournament_id
        end

        unless index_exists?(:matches, :event_id)
          add_index :matches, :event_id
        end

        unless index_exists?(:user_event_participations, [:user_id, :event_id])
          add_index :user_event_participations, [:user_id, :event_id]
        end

        unless index_exists?(:user_match_participations, [:user_id, :match_id])
          add_index :user_match_participations, [:user_id, :match_id]
        end

        unless index_exists?(:user_match_participations, :is_winner)
          add_index :user_match_participations, :is_winner
        end
      end
    end

    # Add counter cache columns if they don't exist
    reversible do |dir|
      dir.up do
        unless column_exists?(:users, :events_count)
          add_column :users, :events_count, :integer, default: 0, null: false
        end

        unless column_exists?(:tournaments, :events_count)
          add_column :tournaments, :events_count, :integer, default: 0, null: false
        end

        unless column_exists?(:events, :matches_count)
          add_column :events, :matches_count, :integer, default: 0, null: false
        end
      end
    end
  end
end