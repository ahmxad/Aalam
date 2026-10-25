require "application_system_test_case"
require_relative "../support/omniauth_helpers"

class SignUpAndSignInTest < ApplicationSystemTestCase
  include OmniauthHelpers

  test "the home page opens in a real browser" do
    visit root_path

    assert_selector "header"
    assert_selector "img[alt='Aalam logo']"
  end

  test "the sign up page says at once that a username is taken" do
    visit signup_path

    fill_in "user[username]", with: users(:one).username

    assert_selector "[data-username-availability-target=hint].text-error", text: "Username has already been taken"
  end

  test "and that a free username is available" do
    visit signup_path

    fill_in "user[username]", with: "brand_new_name"

    assert_selector "[data-username-availability-target=hint].text-success", text: "Username is available"
  end

  test "the GitHub button signs a new person up, from the button to the signed in page" do
    mock_oauth(:github, uid: "9001", email: "browser@example.com", name: "Browser Person", nickname: "browser_person")

    visit new_session_path
    click_button "Continue with GitHub"

    assert_current_path new_oauth_signup_path
    assert_selector "h1", text: "Finish signing up"
    assert_field "user[username]", with: "browser_person"
    assert_text "browser@example.com"

    click_button "Create account"

    assert_text "Welcome to Aalam!"
    assert_selector "[aria-label='Open profile menu']"
  end

  test "someone with an account can log in through the page" do
    log_in_as(users(:one))

    assert_current_path root_path
  end
end
