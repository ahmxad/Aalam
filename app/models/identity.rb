# A way of signing in that belongs to a user, such as their GitHub account
class Identity < ApplicationRecord
  PROVIDER_NAMES = { "github" => "GitHub", "google_oauth2" => "Google" }.freeze

  belongs_to :user

  validates :provider, inclusion: { in: PROVIDER_NAMES.keys }
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }

  def provider_name
    PROVIDER_NAMES.fetch(provider)
  end
end
