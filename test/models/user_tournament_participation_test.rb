# == Schema Information
#
# Table name: user_tournament_participations
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tournament_id :integer          not null
#  user_id       :integer          not null
#
# Indexes
#
#  index_user_tournament_participations_on_tournament_id  (tournament_id)
#  index_user_tournament_participations_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (tournament_id => tournaments.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class UserTournamentParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
