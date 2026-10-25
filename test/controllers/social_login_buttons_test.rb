require "test_helper"

class SocialLoginButtonsTest < ActionDispatch::IntegrationTest
  LOGOS = { "github" => "github", "google_oauth2" => "google" }.freeze

  def assert_social_buttons
    LOGOS.each do |provider, logo|
      name = Identity::PROVIDER_NAMES.fetch(provider)

      assert_select "form[action=?][method=post][data-turbo=false]", "/auth/#{provider}" do
        assert_select "button", text: "Continue with #{name}"
        assert_select "button span.bg-white img[src*=?]", "social_logos/#{logo}"
      end
    end

    # Starting a sign in is a POST only. A plain link would not be accepted.
    assert_select "a[href^='/auth/']", 0
  end

  test "the log in page has a button for every service" do
    get new_session_path

    assert_response :success
    assert_social_buttons
  end

  test "the sign up page has the same buttons" do
    get signup_path

    assert_response :success
    assert_social_buttons
  end

  test "the buttons come after the form, with a divider" do
    get new_session_path

    body = response.body
    assert_operator body.index("Create one") || body.length, :>, body.index("Continue with GitHub")
    assert_operator body.index("Continue with GitHub"), :>, body.index("Password")
    assert_select ".divider", text: "or"
  end

  test "the page for finishing a sign up has no such buttons" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: "800", info: { email: "x@example.com", name: "X", nickname: "x_user" }
    )

    post "/auth/github"
    follow_redirect!
    get new_oauth_signup_path

    assert_response :success
    assert_select "form[action^='/auth/']", 0
  ensure
    OmniAuth.config.mock_auth[:github] = nil
    OmniAuth.config.test_mode = false
  end
end
