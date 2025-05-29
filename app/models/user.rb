# == Schema Information
#
# Table name: users
#
#  id                       :integer          not null, primary key
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
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :omniauthable, omniauth_providers: [:startgg]

  has_many :user_tournament_participations
  has_many :tournaments, through: :user_tournament_participations

  # Add new associations for events and matches
  has_many :user_event_participations
  has_many :events, through: :user_event_participations

  has_many :user_match_participations
  has_many :matches, through: :user_match_participations

  # Convenience method to find winning matches
  def winning_matches
    user_match_participations.where(is_winner: true).map(&:match)
  end

  # Convenience method to find losing matches
  def losing_matches
    user_match_participations.where(is_winner: false).map(&:match)
  end

  def self.from_omniauth(auth)
    # Find an existing user by provider and uid, or initialize a new one
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    # Update the user's attributes with the latest info from Start.gg
    # This will apply to both new and existing users.
    user.email = auth.info.email
    user.tag = auth.info.gamerTag # gamerTag is populated by our strategy

    # Store the OAuth credentials
    user.startgg_access_token = auth.credentials.token
    user.startgg_refresh_token = auth.credentials.refresh_token # If Start.gg provides it
    # Calculate and store expiry time if auth.credentials.expires_at is a Unix timestamp
    user.startgg_token_expires_at = Time.at(auth.credentials.expires_at) if auth.credentials.expires_at.present?

    # If you had a name attribute, you'd update it here too:
    # user.name = auth.info.name

    user.save! # Save the record (either creates or updates)
    user       # Return the user
  end
end
