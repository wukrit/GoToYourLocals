# == Schema Information
#
# Table name: matches
#
#  id              :bigint           not null, primary key
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
#  fk_rails_...  (event_id => events.id)
#
require "test_helper"

class MatchTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
