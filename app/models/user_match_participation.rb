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
#  index_user_match_participations_on_match_id  (match_id)
#  index_user_match_participations_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (match_id => matches.id)
#  fk_rails_...  (user_id => users.id)
#
class UserMatchParticipation < ApplicationRecord
  belongs_to :user
  belongs_to :match
end
