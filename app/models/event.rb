# == Schema Information
#
# Table name: events
#
#  id            :bigint           not null, primary key
#  name          :string
#  num_entrants  :integer
#  slug          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  startgg_id    :integer
#  tournament_id :integer          not null
#
# Indexes
#
#  index_events_on_startgg_id     (startgg_id) UNIQUE
#  index_events_on_tournament_id  (tournament_id)
#
# Foreign Keys
#
#  fk_rails_...  (tournament_id => tournaments.id)
#
class Event < ApplicationRecord
  belongs_to :tournament

  has_many :user_event_participations
  has_many :users, through: :user_event_participations

  has_many :matches

  # Add a unique index for startgg_id to prevent duplicates
  validates :startgg_id, uniqueness: true, presence: true
end
