require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/omniauth_helpers"

class OauthSignupsTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  # Comes back from the service as someone new, which ends at the "Finish signing up" page
  def begin_signup(provider = :github, **attributes)
    options = { uid: "700", email: "oauth.person@example.com", name: "OAuth Person", nickname: "oauth_person" }
    mock_oauth(provider, **options.merge(attributes))

    sign_in_with(provider)
    assert_redirected_to new_oauth_signup_path
  end

  def finish(username: "chosen_name", **extra)
    post oauth_signup_path, params: { user: { username: username }.merge(extra) }
  end

  def emailed_code
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
  end

  # Without a started sign up

  test "the page and the form need a sign up that was started at a service" do
    get new_oauth_signup_path
    assert_redirected_to new_session_path
    assert_equal "Your sign up expired. Please start again.", flash[:alert]

    assert_no_difference "User.count" do
      finish
    end
    assert_redirected_to new_session_path
  end

  test "a signed in user has no use for it" do
    sign_in_as(users(:one))

    get new_oauth_signup_path
    assert_redirected_to root_path

    assert_no_difference "User.count" do
      finish
    end
    assert_redirected_to root_path
  end

  # The page

  test "with an address that the service verified, the page shows it and asks only for a username" do
    begin_signup

    get new_oauth_signup_path

    assert_response :success
    assert_select "h1", "Finish signing up"
    assert_select "p", /You are signing up with GitHub/
    assert_select "input[name='user[username]'][value=oauth_person]"
    assert_select "[data-controller='username-availability'][data-username-availability-url-value=?]", username_availability_path
    assert_select "strong", "oauth.person@example.com"
    assert_select "span", /already verified by GitHub/
    assert_select "input[name='user[email_address]']", 0
  end

  test "without an address, the page asks for one and says why" do
    begin_signup(email: nil)

    get new_oauth_signup_path

    assert_select "input[name='user[email_address]'][type=email]"
    assert_select "p", /GitHub did not share a verified email address/
  end

  test "the page names Google when the person came from Google" do
    begin_signup(:google_oauth2, email: "someone@example.com")

    get new_oauth_signup_path

    assert_select "p", /You are signing up with Google/
    assert_select "span", /already verified by Google/
  end

  test "the page does not show Log in or Sign up in the navbar" do
    begin_signup

    get new_oauth_signup_path

    assert_select "header a[href=?]", new_session_path, 0
    assert_select "header a[href=?]", signup_path, 0
  end

  # Finishing with a verified address

  test "finishing makes a verified account, connects the service and signs the person in" do
    begin_signup

    assert_difference [ "User.count", "Identity.count" ], 1 do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        finish
      end
    end

    assert_redirected_to root_path
    assert_equal "Welcome to Aalam!", flash[:notice]
    assert cookies[:session_id]
    assert_nil session[:pending_oauth]

    user = User.find_by!(username: "chosen_name")
    assert_equal "oauth.person@example.com", user.email_address
    assert user.email_verified?
    assert_not user.password_set?
    assert_not user.admin?
    assert_equal "OAuth Person", user.display_name
    assert_equal [ [ "github", "700" ] ], user.identities.pluck(:provider, :uid)
    assert_equal 1, user.sessions.count
  end

  test "the username is tidied up" do
    begin_signup

    finish(username: "  Chosen_Name ")

    assert User.exists?(username: "chosen_name")
  end

  test "an address typed into the form cannot replace the one the service verified" do
    begin_signup

    finish(email_address: "someone.else@example.com")

    assert_equal "oauth.person@example.com", User.find_by!(username: "chosen_name").email_address
  end

  test "the new account signs in through the service again, and no password opens it" do
    begin_signup
    finish
    delete session_path

    post session_path, params: { login: "oauth.person@example.com", password: "password123" }
    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?

    sign_in_with(:github)
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "someone who sat on an address without proving it cannot block its real owner" do
    squatter = create_unverified_user("squatter")
    begin_signup(email: squatter.email_address)
    assert_not User.exists?(squatter.id)

    finish

    user = User.find_by!(username: "chosen_name")
    assert_equal "squatter@example.com", user.email_address
    assert user.email_verified?
  end

  # Finishing without a verified address

  test "an address typed by the person is checked with a code, and the account waits until then" do
    begin_signup(email: nil)

    assert_difference [ "User.count", "Identity.count", "ActionMailer::Base.deliveries.size" ], 1 do
      finish(email_address: "typed@example.com")
    end

    assert_redirected_to email_verification_path
    assert_equal "Welcome to Aalam! We sent a 6 digit code to t***@example.com.", flash[:notice]
    assert_equal [ "typed@example.com" ], ActionMailer::Base.deliveries.last.to
    assert cookies[:session_id]

    user = User.find_by!(username: "chosen_name")
    assert_not user.email_verified?
    assert_not user.password_set?

    post email_verification_path, params: { otp: emailed_code }
    assert user.reload.email_verified?
  end

  test "an address that Google did not verify is replaced by the one the person types" do
    begin_signup(:google_oauth2, email: "maybe@example.com", email_verified: false)

    finish(email_address: "typed@example.com")

    user = User.find_by!(username: "chosen_name")
    assert_equal "typed@example.com", user.email_address
    assert_not user.email_verified?
    assert_equal [ "typed@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  # What is refused

  test "a username that is taken, wrong or reserved is refused and the sign up stays open" do
    begin_signup

    {
      users(:one).username => "Username has already been taken",
      "ab" => "Username is too short (minimum is 3 characters)",
      "bad name" => "Username can only contain letters, numbers and underscores",
      "admin" => "Username is not available"
    }.each do |username, message|
      assert_no_difference [ "User.count", "Identity.count" ] do
        finish(username: username)
      end

      assert_response 422
      assert_select "[role=alert] li", text: message
      assert session[:pending_oauth], "the sign up should stay open"
    end
  end

  test "without an address from the service the typed one must be a good one" do
    begin_signup(email: nil)

    {
      "" => "Email address can't be blank",
      "not-an-email" => "Email address is invalid",
      users(:one).email_address => "Email address has already been taken"
    }.each do |email, message|
      assert_no_difference "User.count" do
        finish(email_address: email)
      end

      assert_response 422
      assert_select "[role=alert] li", text: message
      assert_select "input[name='user[email_address]']", 1
    end
  end

  test "an address that was taken while the person was choosing is refused" do
    begin_signup
    User.create!(username: "grabbed", email_address: "oauth.person@example.com", password: "password123")

    assert_no_difference "User.count" do
      finish
    end

    assert_response 422
    assert_select "[role=alert] li", text: "Email address has already been taken"
  end

  test "an account of the service that was connected elsewhere in the meantime is refused" do
    begin_signup
    users(:two).identities.create!(provider: "github", uid: "700")

    assert_no_difference [ "User.count", "Identity.count" ] do
      finish
    end

    assert_response 422
  end

  test "a request without the form values gives a 400" do
    begin_signup

    assert_no_difference "User.count" do
      post oauth_signup_path
    end

    assert_response :bad_request
  end
end
