require "test_helper"
require_relative "../support/post_builder"

class ConnectedAccountsViewTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup { @user = users(:one) }

  test "a user with a password sees every service as not connected, each with a Connect button" do
    sign_in_as(@user)

    get edit_account_path

    assert_select "#connected-accounts h2", "Connected accounts"
    assert_select "#connected-accounts li", 2
    assert_select "#connected-accounts li", text: /Not connected/, count: 2

    Identity::PROVIDER_NAMES.each do |provider, name|
      assert_select "#connected-accounts li", text: /#{name}/
      assert_select "#connected-accounts form[action=?][method=post][data-turbo=false] button", "/auth/#{provider}",
                    text: "Connect"
    end
  end

  test "each service shows its logo on a white square" do
    sign_in_as(@user)

    get edit_account_path

    assert_select "#connected-accounts li span.bg-white img[src*=?]", "social_logos/github"
    assert_select "#connected-accounts li span.bg-white img[src*=?]", "social_logos/google"
  end

  test "a connected service shows as connected with a Disconnect button that asks first" do
    identity = @user.identities.create!(provider: "github", uid: "100")
    sign_in_as(@user)

    get edit_account_path

    assert_select "#connected-accounts li", text: /\bConnected\b/, count: 1
    assert_select "#connected-accounts form[action=?][data-turbo-confirm=?]", identity_path(identity),
                  "Disconnect GitHub from your account?" do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", "Disconnect"
    end
    assert_select "#connected-accounts form[action=?]", "/auth/github", 0
    assert_select "#connected-accounts form[action=?]", "/auth/google_oauth2", 1
  end

  test "a user with a password sees no hint about setting one" do
    @user.identities.create!(provider: "github", uid: "100")
    sign_in_as(@user)

    get edit_account_path

    assert_select "#connected-accounts > p", 0
  end

  test "the only way to sign in has no Disconnect button and says why" do
    person = create_oauth_user
    sign_in_as(person)

    get edit_account_path

    assert_select "#connected-accounts li span", "Your only way to sign in"
    assert_select "#connected-accounts form[action=?]", identity_path(person.identities.first), 0
    assert_select "#connected-accounts > p", "Set a password below to be able to disconnect your only sign in service."
  end

  test "with two services and no password both can be disconnected" do
    person = create_oauth_user("both_services", providers: %w[github google_oauth2])
    sign_in_as(person)

    get edit_account_path

    person.identities.each do |identity|
      assert_select "#connected-accounts form[action=?]", identity_path(identity), 1
    end
    assert_select "#connected-accounts li span", text: "Your only way to sign in", count: 0
  end
end

class PasswordSectionTest < ActionDispatch::IntegrationTest
  include PostBuilder

  test "a user with a password sees the form for changing it" do
    sign_in_as(users(:one))

    get edit_account_path

    assert_select "form#password[action=?]", account_password_path do
      assert_select "input[name='user[current_password]'][type=password]"
      assert_select "input[name='user[password]'][type=password]"
      assert_select "input[name='user[password_confirmation]'][type=password]"
      assert_select "input[type=submit][value=?]", "Change password"
    end
    assert_select "form[action=?]", account_password_setup_path, 0
  end

  test "a user without a password sees how to set one instead" do
    sign_in_as(create_oauth_user)

    get edit_account_path

    assert_select "form#password", 0
    assert_select "section#password h2", "Password"
    assert_select "section#password p", /You signed up with GitHub, so this account has no password yet/
    assert_select "section#password form[action=?] button", account_password_setup_path,
                  text: "Email me a link to set a password"
  end

  test "the text names every service the person signed up with" do
    sign_in_as(create_oauth_user("both_services", providers: %w[github google_oauth2]))

    get edit_account_path

    assert_select "section#password p", text: /GitHub/
    assert_select "section#password p", text: /Google/
  end
end

class PasswordSetupRequestTest < ActionDispatch::IntegrationTest
  include PostBuilder

  test "a visitor who is not signed in is sent to log in" do
    post account_password_setup_path

    assert_redirected_to new_session_path
    assert_enqueued_emails 0
  end

  test "a user without a password gets an email with a link to set one" do
    person = create_oauth_user
    sign_in_as(person)

    post account_password_setup_path

    assert_redirected_to edit_account_path
    assert_equal "We emailed a link to o***@example.com.", flash[:notice]
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ person ]
  end

  test "a user who already has a password is sent back and nothing is emailed" do
    sign_in_as(users(:one))

    post account_password_setup_path

    assert_redirected_to edit_account_path
    assert_nil flash[:notice]
    assert_enqueued_emails 0
  end

  test "an address that was never verified has to be verified first" do
    sign_in_as(create_oauth_user("unverified_oauth", verified: false))

    post account_password_setup_path

    assert_redirected_to email_verification_path
    assert_equal "Verify your email first, then we can send the link.", flash[:alert]
    assert_enqueued_emails 0
  end

  test "the form for changing a password cannot be used to set the first one" do
    person = create_oauth_user
    sign_in_as(person)

    assert_no_changes -> { person.reload.password_digest } do
      patch account_password_path, params: {
        user: { current_password: "guess", password: "new-password-123", password_confirmation: "new-password-123" }
      }
    end

    assert_response 422
    assert_select "[role=alert] li", "Current password is incorrect"
    assert_not person.reload.password_set?
  end

  test "the emailed link sets a password, which opens the account and frees the last service" do
    person = create_oauth_user
    sign_in_as(person)
    post account_password_setup_path
    token = person.password_reset_token

    put password_path(token), params: { password: "brand-new-pass-1", password_confirmation: "brand-new-pass-1" }
    assert_redirected_to new_session_path

    person.reload
    assert person.password_set?
    assert person.authenticate("brand-new-pass-1")
    assert person.can_disconnect?(person.identities.first)

    post session_path, params: { login: person.email_address, password: "brand-new-pass-1" }
    assert_redirected_to root_path

    get edit_account_path
    assert_select "form#password"
    assert_select "#connected-accounts li span", text: "Your only way to sign in", count: 0
  end
end
