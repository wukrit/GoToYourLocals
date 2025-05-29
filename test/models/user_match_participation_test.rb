# == Schema Information
#
# Table name: user_match_participations
#
#  id         :bigint           not null, primary key
#  is_winner  :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  match_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_user_match_participations_on_is_winner             (is_winner)
#  index_user_match_participations_on_match_id              (match_id)
#  index_user_match_participations_on_user_id               (user_id)
#  index_user_match_participations_on_user_id_and_match_id  (user_id,match_id)
#
# Foreign Keys
#
#  fk_rails_...  (match_id => matches.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class UserMatchParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
