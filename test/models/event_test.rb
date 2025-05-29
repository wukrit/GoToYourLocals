# == Schema Information
#
# Table name: events
#
#  id            :bigint           not null, primary key
#  matches_count :integer          default(0), not null
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
require "test_helper"

class EventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
