# == Schema Information
#
# Table name: users
#
#  id                  :integer          not null, primary key
#  email               :string           default(""), not null
#  provider            :string
#  remember_created_at :datetime
#  tag                 :string
#  uid                 :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :omniauthable, omniauth_providers: [:startgg]

  def self.from_omniauth(auth)
    # Find an existing user by provider and uid, or initialize a new one
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    # Update the user's attributes with the latest info from Start.gg
    # This will apply to both new and existing users.
    user.email = auth.info.email
    user.tag = auth.info.gamerTag # gamerTag is populated by our strategy

    # If you had a name attribute, you'd update it here too:
    # user.name = auth.info.name

    user.save! # Save the record (either creates or updates)
    user       # Return the user
  end
end
