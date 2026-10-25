require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/omniauth_helpers"

class IdentitiesControllerTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include OmniauthHelpers

  setup do
    @user = users(:one)
    @github = @user.identities.create!(provider: "github", uid: "100")
  end

  test "a visitor who is not signed in is sent to log in and nothing is removed" do
    assert_no_difference "Identity.count" do
      delete identity_path(@github)
    end

    assert_redirected_to new_session_path
  end

  test "a user with a password can disconnect a service" do
    sign_in_as(@user)

    assert_difference "Identity.count", -1 do
      delete identity_path(@github)
    end

    assert_response :see_other
    assert_redirected_to edit_account_path
    assert_equal "GitHub was disconnected.", flash[:notice]
    assert_equal 0, @user.identities.count
  end

  test "disconnecting leaves the account and its sessions alone" do
    sign_in_as(@user)

    assert_no_difference [ "User.count", "Session.count" ] do
      delete identity_path(@github)
    end
  end

  test "the same goes for Google" do
    google = @user.identities.create!(provider: "google_oauth2", uid: "200")
    sign_in_as(@user)

    delete identity_path(google)

    assert_equal "Google was disconnected.", flash[:notice]
    assert_equal [ "github" ], @user.identities.pluck(:provider)
  end

  test "the only way to sign in cannot be removed" do
    person = create_oauth_user
    sign_in_as(person)

    assert_no_difference "Identity.count" do
      delete identity_path(person.identities.first)
    end

    assert_response :see_other
    assert_redirected_to edit_account_path
    assert_equal "GitHub is your only way to sign in. Set a password first.", flash[:alert]
  end

  test "with two services one can go, and then the other cannot" do
    person = create_oauth_user("two_services", providers: %w[github google_oauth2])
    sign_in_as(person)
    github, google = person.identities.order(:id).to_a

    delete identity_path(github)
    assert_equal "GitHub was disconnected.", flash[:notice]

    assert_no_difference "Identity.count" do
      delete identity_path(google)
    end
    assert_equal "Google is your only way to sign in. Set a password first.", flash[:alert]
  end

  test "once a password is set the last service can go too" do
    person = create_oauth_user
    sign_in_as(person)
    person.update!(password: "new-password-123")

    assert_difference "Identity.count", -1 do
      delete identity_path(person.identities.first)
    end

    assert_equal "GitHub was disconnected.", flash[:notice]
  end

  test "the identity of another user cannot be removed" do
    sign_in_as(users(:two))

    assert_no_difference "Identity.count" do
      delete identity_path(@github)
    end

    assert_response :not_found
  end

  test "an identity that does not exist gives a 404" do
    sign_in_as(@user)

    delete identity_path(0)

    assert_response :not_found
  end

  test "a disconnected service can be connected again" do
    sign_in_as(@user)
    delete identity_path(@github)
    mock_oauth(:github, uid: "100")

    assert_difference "Identity.count", 1 do
      sign_in_with(:github)
    end

    assert_equal "GitHub is now connected to your account.", flash[:notice]
  end
end
