# == Schema Information
#
# Table name: users
#
#  id                       :bigint           not null, primary key
#  email                    :string           default(""), not null
#  provider                 :string
#  remember_created_at      :datetime
#  startgg_access_token     :string
#  startgg_refresh_token    :string
#  startgg_token_expires_at :datetime
#  tag                      :string
#  uid                      :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
