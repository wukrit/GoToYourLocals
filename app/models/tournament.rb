# == Schema Information
#
# Table name: tournaments
#
#  id           :bigint           not null, primary key
#  city         :string
#  country_code :string
#  end_at       :datetime
#  events_count :integer          default(0), not null
#  images       :json
#  is_online    :boolean
#  name         :string
#  slug         :string
#  start_at     :datetime
#  state        :string
#  venue_name   :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  startgg_id   :bigint
#
# Indexes
#
#  index_tournaments_on_startgg_id  (startgg_id) UNIQUE
#
class Tournament < ApplicationRecord
  has_many :user_tournament_participations
  has_many :users, through: :user_tournament_participations

  # Add events association
  has_many :events
end
