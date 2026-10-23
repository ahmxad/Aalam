# Signing in through GitHub or Google without leaving the test: in OmniAuth's test mode the
# controller is handed a prepared answer, as if the service had just sent the person back
module OmniauthHelpers
  extend ActiveSupport::Concern

  included do
    setup { OmniAuth.config.test_mode = true }

    teardown do
      OmniAuth.config.mock_auth[:github] = nil
      OmniAuth.config.mock_auth[:google_oauth2] = nil
      OmniAuth.config.test_mode = false
    end
  end

  # What the service will say about the person. Google tells whether it verified the address
  # and has no nickname, GitHub has a nickname and only gives an address it verified.
  def mock_oauth(provider, uid: "1001", email: "oauth.person@example.com", name: "OAuth Person",
                 nickname: "oauth_person", email_verified: true)
    info = { name: name, email: email }
    if provider == :google_oauth2
      info[:email_verified] = email_verified
    else
      info[:nickname] = nickname
    end

    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(provider: provider.to_s, uid: uid, info: info)
  end

  # The sign in fails at the service, or the person cancels there
  def mock_oauth_failure(provider, reason = :invalid_credentials)
    OmniAuth.config.mock_auth[provider] = reason
  end

  # Presses "Continue with ..." and comes back from the service. Afterwards the last answer is the
  # one our own callback gave, which is what the tests look at.
  def sign_in_with(provider)
    post "/auth/#{provider}"
    assert_redirected_to "/auth/#{provider}/callback"
    follow_redirect!
  end
end
