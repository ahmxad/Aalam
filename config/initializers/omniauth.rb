# Signing in with other services. Their keys live in the Rails credentials.
Rails.application.config.middleware.use OmniAuth::Builder do
  # user:email lets the strategy return the primary email address, and only when the service has verified it
  provider :github,
           Rails.application.credentials.dig(:github, :client_id),
           Rails.application.credentials.dig(:github, :client_secret),
           scope: "user:email"
end

OmniAuth.config.logger = Rails.logger

# A failed or cancelled sign in goes to our own page instead of raising an error
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
