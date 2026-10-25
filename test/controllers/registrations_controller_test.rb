require "test_helper"
require_relative "../support/image_fixtures"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ImageFixtures

  def valid_params(overrides = {})
    {
      user: {
        username: "fresh_user",
        email_address: "fresh@example.com",
        password: "password123",
        password_confirmation: "password123"
      }.merge(overrides)
    }
  end

  # The form

  test "new shows the sign up form with its live helpers attached" do
    get signup_path

    assert_response :success
    assert_select "form[action=?][enctype='multipart/form-data']", registration_path
    assert_select "input[name='user[username]']"
    assert_select "input[name='user[email_address]'][type=email]"
    assert_select "input[name='user[password]'][type=password]"
    assert_select "input[name='user[password_confirmation]'][type=password]"
    assert_select "input[name='user[avatar_upload]'][type=file]"
    assert_select "[data-controller='username-availability'][data-username-availability-url-value=?]", username_availability_path
    assert_select "[data-controller='password-strength']"
    assert_select "[data-controller='avatar-preview']"
  end

  test "the sign up page links to the login page" do
    get signup_path

    assert_select "a[href=?]", new_session_path, text: "Log in"
  end

  test "the registration path shows the same form" do
    get new_registration_path

    assert_response :success
  end

  test "a signed in user is sent away from the sign up page" do
    sign_in_as(users(:one))

    get signup_path

    assert_redirected_to root_path
  end

  test "a signed in user cannot create another account" do
    sign_in_as(users(:one))

    assert_no_difference "User.count" do
      post registration_path, params: valid_params
    end

    assert_redirected_to root_path
  end

  # Creating an account

  test "create makes the account, signs the user in and sends them to verify their email" do
    assert_difference "User.count", 1 do
      post registration_path, params: valid_params
    end

    assert_redirected_to email_verification_path
    assert cookies[:session_id]
    assert_includes flash[:notice], "Welcome to Aalam!"

    user = User.find_by!(username: "fresh_user")
    assert_equal "fresh@example.com", user.email_address
    assert_equal 1, user.sessions.count
    assert_not user.email_verified?
  end

  test "create normalizes the username and the email address" do
    post registration_path, params: valid_params(username: "  Fresh_User ", email_address: " Fresh@Example.COM ")

    user = User.find_by!(username: "fresh_user")
    assert_equal "fresh@example.com", user.email_address
  end

  test "create remembers the page the user was trying to open, for after the verification" do
    get admin_root_path
    assert_redirected_to new_session_path

    post registration_path, params: valid_params

    assert_redirected_to email_verification_path
    assert_equal admin_root_url, session[:return_to_after_authenticating]
  end

  test "create never makes the new user an admin" do
    post registration_path, params: valid_params(admin: true)

    assert_not User.find_by!(username: "fresh_user").admin?
  end

  test "the new user can log in with the username and the password, and lands on the verification page" do
    post registration_path, params: valid_params
    delete session_path

    post session_path, params: { login: "fresh_user", password: "password123" }

    assert_redirected_to email_verification_path
    assert cookies[:session_id]
  end

  # Invalid data

  test "create with a taken username shows an error and keeps what was typed" do
    assert_no_difference "User.count" do
      post registration_path, params: valid_params(username: users(:one).username)
    end

    assert_response 422
    assert_select "[role=alert] li", text: "Username has already been taken"
    assert_select "input[name='user[username]'][value=?]", users(:one).username
    assert_select "input[type=password][value]", 0
    assert_nil cookies[:session_id]
  end

  test "create with invalid data shows the matching error" do
    {
      { username: "ab" } => "Username is too short (minimum is 3 characters)",
      { username: "bad name" } => "Username can only contain letters, numbers and underscores",
      { username: "admin" } => "Username is not available",
      { email_address: "not-an-email" } => "Email address is invalid",
      { email_address: users(:one).email_address } => "Email address has already been taken",
      { password: "short", password_confirmation: "short" } => "Password is too short (minimum is 8 characters)",
      { password_confirmation: "different123" } => "Password confirmation doesn't match Password"
    }.each do |overrides, message|
      assert_no_difference "User.count" do
        post registration_path, params: valid_params(overrides)
      end

      assert_response 422
      assert_select "[role=alert] li", text: message
    end
  end

  # Profile picture

  test "create without a profile picture is fine" do
    post registration_path, params: valid_params

    assert_not User.find_by!(username: "fresh_user").avatar.attached?
  end

  test "create with a profile picture stores it as a WebP" do
    post registration_path, params: valid_params(avatar_upload: uploaded_image(:jpeg, filename: "me.jpg"))

    user = User.find_by!(username: "fresh_user")
    assert user.avatar_stored?
    assert_equal "image/webp", user.avatar.content_type
  end

  test "create with a file that is not an image shows an error and creates nothing" do
    not_an_image = uploaded_file("not an image", filename: "me.jpg", content_type: "image/jpeg")

    assert_no_difference "User.count" do
      post registration_path, params: valid_params(avatar_upload: not_an_image)
    end

    assert_response 422
    assert_select "[role=alert] li", text: "Avatar must be a JPEG, PNG or WebP"
  end
end
