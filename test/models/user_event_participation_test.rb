# == Schema Information
#
# Table name: user_event_participations
#
#  id              :bigint           not null, primary key
#  final_placement :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  entrant_id      :integer
#  event_id        :integer          not null
#  user_id         :integer          not null
#
# Indexes
#
#  index_user_event_participations_on_event_id              (event_id)
#  index_user_event_participations_on_user_id               (user_id)
#  index_user_event_participations_on_user_id_and_event_id  (user_id,event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class UserEventParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
