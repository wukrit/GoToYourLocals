# == Schema Information
#
# Table name: matches
#
#  id              :integer          not null, primary key
#  display_score   :string
#  full_round_text :string
#  identifier      :string
#  round           :string
#  round_number    :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :integer          not null
#  loser_id        :integer
#  startgg_id      :integer
#  winner_id       :integer
#
# Indexes
#
#  index_matches_on_event_id    (event_id)
#  index_matches_on_startgg_id  (startgg_id) UNIQUE
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class Match < ApplicationRecord
  belongs_to :event

  has_many :user_match_participations
  has_many :users, through: :user_match_participations

  # Add a unique index for startgg_id to prevent duplicates
  validates :startgg_id, uniqueness: true, presence: true

  # Convenience methods to get winner and loser
  def winner
    user_match_participations.find_by(is_winner: true)&.user
  end

  def loser
    user_match_participations.find_by(is_winner: false)&.user
  end

  # Get opponent for a specific user
  def opponent_for(user)
    opponents = users.where.not(id: user.id)
    opponents.first
  end

  # Get opponent tag for a specific user
  def opponent_tag_for(user)
    opponent = opponent_for(user)
    opponent&.tag || "Unknown"
  end

  # Get result display for a user
  def result_display_for(user)
    if display_score.present?
      display_score
    elsif full_round_text.present?
      "#{full_round_text}"
    else
      is_winner = user_match_participations.find_by(user: user)&.is_winner
      is_winner ? "Win" : "Loss"
    end
  end
end
