require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/omniauth_helpers"

class OmniauthKnownIdentityTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  setup { @user = users(:one) }

  test "an identity that is already connected signs in its user" do
    @user.identities.create!(provider: "github", uid: "100")
    mock_oauth(:github, uid: "100")

    assert_no_difference "User.count" do
      assert_difference "Session.count", 1 do
        sign_in_with(:github)
      end
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "it works the same way for Google" do
    @user.identities.create!(provider: "google_oauth2", uid: "100")
    mock_oauth(:google_oauth2, uid: "100")

    assert_difference "Session.count", 1 do
      sign_in_with(:google_oauth2)
    end

    assert_redirected_to root_path
  end

  test "the connected identity decides who signs in, whatever address the service reports now" do
    @user.identities.create!(provider: "github", uid: "100")
    mock_oauth(:github, uid: "100", email: users(:two).email_address)

    sign_in_with(:github)

    assert_equal 1, @user.sessions.count
    assert_equal 0, users(:two).sessions.count
  end

  test "the same id at another service is a different person" do
    @user.identities.create!(provider: "github", uid: "100")
    mock_oauth(:google_oauth2, uid: "100", email: "someone.else@example.com")

    assert_no_difference "Session.count" do
      sign_in_with(:google_oauth2)
    end

    assert_redirected_to new_oauth_signup_path
  end

  test "the page the person wanted is opened after signing in" do
    @user.identities.create!(provider: "github", uid: "100")
    mock_oauth(:github, uid: "100")

    get saved_posts_path
    assert_redirected_to new_session_path

    sign_in_with(:github)

    assert_redirected_to saved_posts_url
  end

  test "a user who never verified their address is sent to the verification page" do
    person = create_unverified_user("unverified_gh")
    person.identities.create!(provider: "github", uid: "101")
    mock_oauth(:github, uid: "101")

    sign_in_with(:github)

    assert_redirected_to email_verification_path
    assert cookies[:session_id]
  end
end

class OmniauthConnectTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "a signed in user can connect GitHub to their account" do
    mock_oauth(:github, uid: "200")

    assert_difference "Identity.count", 1 do
      sign_in_with(:github)
    end

    assert_redirected_to edit_account_path
    assert_equal "GitHub is now connected to your account.", flash[:notice]
    assert_equal "200", @user.identities.find_by!(provider: "github").uid
  end

  test "and Google too" do
    mock_oauth(:google_oauth2, uid: "201")

    assert_difference "Identity.count", 1 do
      sign_in_with(:google_oauth2)
    end

    assert_equal "Google is now connected to your account.", flash[:notice]
  end

  test "connecting does not sign anyone in again" do
    mock_oauth(:github, uid: "200")

    assert_no_difference "Session.count" do
      sign_in_with(:github)
    end
  end

  test "connecting something that is already connected says so and changes nothing" do
    @user.identities.create!(provider: "github", uid: "200")
    mock_oauth(:github, uid: "200")

    assert_no_difference "Identity.count" do
      sign_in_with(:github)
    end

    assert_redirected_to edit_account_path
    assert_equal "GitHub was already connected to your account.", flash[:notice]
  end

  test "an account of the service that belongs to another user cannot be taken over" do
    users(:two).identities.create!(provider: "github", uid: "300")
    mock_oauth(:github, uid: "300")

    assert_no_difference "Identity.count" do
      sign_in_with(:github)
    end

    assert_redirected_to edit_account_path
    assert_equal "That GitHub account is already connected to a different account.", flash[:alert]
    assert_equal 0, @user.identities.count
  end

  test "a second account of the same service cannot be added" do
    @user.identities.create!(provider: "github", uid: "1")
    mock_oauth(:github, uid: "2")

    assert_no_difference "Identity.count" do
      sign_in_with(:github)
    end

    assert_redirected_to edit_account_path
    assert_equal "Provider has already been taken", flash[:alert]
  end

  test "the address of the service plays no part when connecting" do
    mock_oauth(:github, uid: "200", email: users(:two).email_address)

    sign_in_with(:github)

    assert_equal [ @user ], Identity.where(provider: "github", uid: "200").map(&:user)
    assert_equal 0, users(:two).identities.count
  end
end

class OmniauthNewPersonTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  test "a new person is taken to finish signing up, and nothing is created yet" do
    mock_oauth(:github, uid: "500", email: "newbie@example.com", name: "New Bie", nickname: "newbie")

    assert_no_difference [ "User.count", "Identity.count", "Session.count" ] do
      sign_in_with(:github)
    end

    assert_redirected_to new_oauth_signup_path
    assert_nil cookies[:session_id]
    assert_equal(
      { "provider" => "github", "uid" => "500", "email" => "newbie@example.com",
        "name" => "New Bie", "username" => "newbie" },
      session[:pending_oauth]
    )
  end

  test "GitHub's nickname is suggested as the username" do
    mock_oauth(:github, nickname: "Octo-Cat")

    sign_in_with(:github)

    assert_equal "octo_cat", session[:pending_oauth]["username"]
  end

  test "Google has no nickname, so the start of the address is suggested" do
    mock_oauth(:google_oauth2, email: "john.doe@example.com")

    sign_in_with(:google_oauth2)

    assert_equal "john_doe", session[:pending_oauth]["username"]
  end

  test "a suggestion that is taken or reserved gets a number" do
    mock_oauth(:github, nickname: users(:one).username)
    sign_in_with(:github)
    assert_equal "user_one2", session[:pending_oauth]["username"]

    mock_oauth(:github, nickname: "admin")
    sign_in_with(:github)
    assert_equal "admin2", session[:pending_oauth]["username"]
  end

  test "an address that Google did not verify is not kept and not trusted" do
    mock_oauth(:google_oauth2, email: "maybe@example.com", email_verified: false)

    sign_in_with(:google_oauth2)

    assert_redirected_to new_oauth_signup_path
    assert_nil session[:pending_oauth]["email"]
  end

  test "a service that gave no address leaves it to the person" do
    mock_oauth(:github, email: nil)

    sign_in_with(:github)

    assert_redirected_to new_oauth_signup_path
    assert_nil session[:pending_oauth]["email"]
  end

  test "a very long name is cut to fit" do
    mock_oauth(:github, name: "n" * 80)

    sign_in_with(:github)

    assert_equal "n" * 50, session[:pending_oauth]["name"]
  end

  test "a missing name is left empty" do
    mock_oauth(:github, name: "  ")

    sign_in_with(:github)

    assert_nil session[:pending_oauth]["name"]
  end
end

class OmniauthExistingAccountTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  test "a verified account with the same address is connected and signed in" do
    mock_oauth(:github, uid: "600", email: "one@example.com")

    assert_no_difference "User.count" do
      assert_difference [ "Identity.count", "Session.count" ], 1 do
        sign_in_with(:github)
      end
    end

    assert_redirected_to root_path
    assert_equal "GitHub is now connected to your account.", flash[:notice]
    assert_equal users(:one), Identity.find_by!(provider: "github", uid: "600").user
    assert_nil session[:pending_oauth]
  end

  test "the same goes for Google when it verified the address" do
    mock_oauth(:google_oauth2, uid: "601", email: "one@example.com", email_verified: true)

    assert_difference [ "Identity.count", "Session.count" ], 1 do
      sign_in_with(:google_oauth2)
    end

    assert_equal "Google is now connected to your account.", flash[:notice]
  end

  test "the address matches whatever its letter case" do
    mock_oauth(:github, uid: "602", email: "ONE@Example.com")

    assert_no_difference "User.count" do
      sign_in_with(:github)
    end

    assert_equal users(:one), Identity.find_by!(provider: "github", uid: "602").user
  end

  test "an address that Google did not verify never connects to the account that has it" do
    mock_oauth(:google_oauth2, uid: "603", email: "one@example.com", email_verified: false)

    assert_no_difference [ "Identity.count", "User.count", "Session.count" ] do
      sign_in_with(:google_oauth2)
    end

    assert_redirected_to new_oauth_signup_path
    assert_nil cookies[:session_id]
    assert User.exists?(users(:one).id)
  end

  test "an account whose address was never proved does not keep it" do
    squatter = create_unverified_user("squatter")
    mock_oauth(:github, uid: "604", email: squatter.email_address)

    assert_difference "User.count", -1 do
      sign_in_with(:github)
    end

    assert_not User.exists?(squatter.id)
    assert_redirected_to new_oauth_signup_path
    assert_equal squatter.email_address, session[:pending_oauth]["email"]
    assert_nil cookies[:session_id]
  end

  test "an unverified admin account is never removed this way" do
    admin = User.create!(username: "unverified_admin", email_address: "unverified-admin@example.com",
                         password: "password123", admin: true)
    mock_oauth(:github, uid: "605", email: admin.email_address)

    assert_no_difference "User.count" do
      sign_in_with(:github)
    end

    assert User.exists?(admin.id)
    assert_redirected_to new_oauth_signup_path
  end

  test "an account that already has another GitHub connected cannot be reached this way" do
    users(:one).identities.create!(provider: "github", uid: "1")
    mock_oauth(:github, uid: "2", email: "one@example.com")

    assert_no_difference [ "Identity.count", "Session.count" ] do
      sign_in_with(:github)
    end

    assert_redirected_to new_session_path
    assert_equal "That account already has a different GitHub account connected. Log in with your password instead.",
                 flash[:alert]
    assert_nil cookies[:session_id]
  end
end

class OmniauthFailureTest < ActionDispatch::IntegrationTest
  include OmniauthHelpers

  def assert_sent_back_to_log_in
    assert_redirected_to new_session_path
    assert_equal "We could not sign you in with that service. Please try again or use another way to log in.",
                 flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "a failed or cancelled sign in goes back to the log in page with a message" do
    %i[invalid_credentials access_denied].each do |reason|
      mock_oauth_failure(:github, reason)

      sign_in_with(:github)
      assert_match %r{/auth/failure\?message=#{reason}}, response.location

      follow_redirect!
      assert_sent_back_to_log_in
    end
  end

  test "it is the same for Google" do
    mock_oauth_failure(:google_oauth2, :access_denied)

    sign_in_with(:google_oauth2)
    follow_redirect!

    assert_sent_back_to_log_in
  end

  test "the failure page can be opened directly" do
    get "/auth/failure", params: { message: "access_denied", strategy: "github" }

    assert_sent_back_to_log_in
  end

  test "an answer without an id is refused" do
    mock_oauth(:github, uid: "")

    assert_no_difference [ "User.count", "Identity.count", "Session.count" ] do
      sign_in_with(:github)
    end

    assert_sent_back_to_log_in
    assert_nil session[:pending_oauth]
  end

  test "a service that is not supported is not found" do
    get "/auth/facebook/callback"
    assert_response :not_found

    post "/auth/facebook"
    assert_response :not_found
  end
end
