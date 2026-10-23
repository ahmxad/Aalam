# Signing in with other services. Their keys live in the Rails credentials.
Rails.application.config.middleware.use OmniAuth::Builder do
  # user:email lets the strategy return the primary email address, and only when the service has verified it
  provider :github,
           Rails.application.credentials.dig(:github, :client_id),
           Rails.application.credentials.dig(:github, :client_secret),
           scope: "user:email"

  # access_type online: we only need to know who the person is, not to keep access to their Google account.
  # select_account: Google always asks which account to use, which helps people who have several.
  provider :google_oauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret),
           scope: "email,profile",
           access_type: "online",
           prompt: "select_account"
end

OmniAuth.config.logger = Rails.logger

# A failed or cancelled sign in goes to our own page instead of raising an error
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
