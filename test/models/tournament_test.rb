# == Schema Information
#
# Table name: tournaments
#
#  id           :bigint           not null, primary key
#  city         :string
#  country_code :string
#  end_at       :datetime
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
require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
