require "test_helper"
require_relative "../support/image_fixtures"

class NavbarTest < ActionDispatch::IntegrationTest
  include ImageFixtures

  # A guest on a normal page

  test "a guest sees Log in and Sign up in the navbar and the mobile menu" do
    get root_path

    assert_select "header .hidden.lg\\:flex a[href=?]", new_session_path, text: "Log in"
    assert_select "header .hidden.lg\\:flex a[href=?]", signup_path, text: "Sign up"
    assert_select "header ul.menu a[href=?]", new_session_path, text: "Log in"
    assert_select "header ul.menu a[href=?]", signup_path, text: "Sign up"
  end

  test "a guest sees no profile menu and no Log out button" do
    get root_path

    assert_select "header [aria-label='Open profile menu']", 0
    assert_select "header .dropdown-content", 0
    assert_select "header form[action=?]", session_path, 0
  end

  # A signed in user

  test "a signed in user sees the profile menu instead of Log in and Sign up" do
    sign_in_as(users(:one))

    get root_path

    assert_select "header [role=button][aria-label='Open profile menu']", 1
    assert_select "header a[href=?]", new_session_path, 0
    assert_select "header a[href=?]", signup_path, 0
  end

  test "the profile menu shows the name, the username and the three actions" do
    user = users(:one)
    user.update!(display_name: "Shown Name")
    sign_in_as(user)

    get root_path

    assert_select "header .dropdown-content p.font-semibold", "Shown Name"
    assert_select "header .dropdown-content p", "@#{user.username}"
    assert_select "header .dropdown-content a[href=?]", profile_path(user.username), text: "Profile"
    assert_select "header .dropdown-content a[href=?]", edit_account_path, text: "Account settings"
    assert_select "header .dropdown-content form[action=?] button", session_path, text: "Log out"
  end

  test "the profile menu shows the username when there is no display name" do
    user = users(:one)
    sign_in_as(user)

    get root_path

    assert_select "header .dropdown-content p.font-semibold", user.username
  end

  test "Log out is only inside the profile menu, and it sends a DELETE request" do
    sign_in_as(users(:one))

    get root_path

    assert_select "header form[action=?]", session_path, count: 1
    assert_select "header .dropdown-content form[action=?]", session_path, count: 1
    assert_select "header .dropdown-content form[action=?] input[name=_method][value=delete]", session_path
  end

  test "the menu button shows the first letter when there is no picture" do
    user = users(:one)
    sign_in_as(user)

    get root_path

    assert_select "header [role=button] .avatar-placeholder span", user.public_name.first.upcase
    assert_select "header [role=button] .avatar img", 0
  end

  test "the menu button shows the profile picture when there is one" do
    user = users(:one)
    user.avatar_upload = uploaded_image(:jpeg)
    user.save!
    sign_in_as(user)

    get root_path

    assert_select "header [role=button] .avatar img[alt=?]", "#{user.public_name} profile picture"
    assert_select "header [role=button] .avatar-placeholder", 0
  end

  test "text written by the user is escaped in the menu" do
    user = users(:one)
    user.update!(display_name: "<b>Bold</b>")
    sign_in_as(user)

    get root_path

    assert_not_includes response.body, "<b>Bold</b>"
    assert_includes response.body, "&lt;b&gt;Bold&lt;/b&gt;"
  end

  test "the profile menu also shows on admin pages" do
    sign_in_as(users(:two))

    get admin_root_path

    assert_response :success
    assert_select "header [aria-label='Open profile menu']", 1
  end

  test "the mobile menu has no Log in or Sign up for a signed in user" do
    sign_in_as(users(:one))

    get root_path

    assert_select "header ul.menu a[href=?]", new_session_path, 0
    assert_select "header ul.menu a[href=?]", signup_path, 0
  end

  # Log in and sign up pages

  test "the log in page has no Log in or Sign up in the navbar but links to sign up in the form" do
    get new_session_path

    assert_select "header a[href=?]", new_session_path, 0
    assert_select "header a[href=?]", signup_path, 0
    assert_select "main a[href=?]", signup_path, text: "Create one"
  end

  test "the sign up page has no Log in or Sign up in the navbar but links to log in in the form" do
    get signup_path

    assert_select "header a[href=?]", new_session_path, 0
    assert_select "header a[href=?]", signup_path, 0
    assert_select "main a[href=?]", new_session_path, text: "Log in"
  end

  test "a failed sign up keeps the navbar clean as well" do
    post registration_path, params: { user: { username: "ab" } }

    assert_response 422
    assert_select "header a[href=?]", new_session_path, 0
    assert_select "header a[href=?]", signup_path, 0
  end

  test "other pages that guests can open still show Log in and Sign up" do
    get new_password_path

    assert_select "header a[href=?]", new_session_path, text: "Log in"
    assert_select "header a[href=?]", signup_path, text: "Sign up"
  end

  # Error pages, which ask the navbar the same question

  test "an error page shows the profile menu to a signed in user" do
    sign_in_as(users(:one))

    get "/404"

    assert_select "header [aria-label='Open profile menu']", 1
  end

  test "an error page shows Log in and Sign up to a guest" do
    get "/404"

    assert_select "header a[href=?]", new_session_path, text: "Log in"
    assert_select "header [aria-label='Open profile menu']", 0
  end

  test "an error page treats a broken session cookie as signed out instead of failing" do
    cookies[:session_id] = "this-is-not-a-valid-session-cookie"

    get "/404"

    assert_select "header a[href=?]", new_session_path, text: "Log in"
    assert_select "header [aria-label='Open profile menu']", 0
  end
end
