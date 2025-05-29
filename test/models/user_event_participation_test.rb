# == Schema Information
#
# Table name: user_event_participations
#
#  id              :integer          not null, primary key
#  final_placement :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  entrant_id      :integer
#  event_id        :integer          not null
#  user_id         :integer          not null
#
# Indexes
#
#  index_user_event_participations_on_event_id  (event_id)
#  index_user_event_participations_on_user_id   (user_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#  user_id   (user_id => users.id)
#
require "test_helper"

class UserEventParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
