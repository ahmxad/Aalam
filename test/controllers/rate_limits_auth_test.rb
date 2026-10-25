require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/omniauth_helpers"
require_relative "../support/rate_limit_helpers"

class RateLimitHelperTest < ActionDispatch::IntegrationTest
  include RateLimitHelpers

  def failed_login
    post session_path, params: { login: "nobody", password: "wrong-password" }
  end

  test "without the helper the test environment counts nothing, so nothing is limited" do
    12.times { failed_login }

    assert_equal "Try another username, email address or password.", flash[:alert]
  end

  test "with the helper the limit applies" do
    with_rate_limits do
      11.times { failed_login }
    end

    assert_equal "Try again later.", flash[:alert]
  end

  test "every use of the helper starts with a fresh count" do
    2.times do
      with_rate_limits do
        10.times { failed_login }

        assert_equal "Try another username, email address or password.", flash[:alert]
      end
    end
  end
end

class SessionsRateLimitTest < ActionDispatch::IntegrationTest
  include RateLimitHelpers

  def log_in(login, password)
    post session_path, params: { login: login, password: password }
  end

  test "the eleventh log in attempt in three minutes is refused, even with the right password" do
    with_rate_limits do
      10.times { log_in("nobody", "wrong-password") }
      assert_equal "Try another username, email address or password.", flash[:alert]

      log_in(users(:one).username, "password")
    end

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
    assert cookies[:session_id].blank?
  end

  test "the right password works while the limit has not been reached" do
    with_rate_limits do
      9.times { log_in("nobody", "wrong-password") }

      log_in(users(:one).username, "password")
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "only attempts to log in are counted, not the page with the form" do
    with_rate_limits do
      15.times { get new_session_path }
      log_in(users(:one).username, "password")
    end

    assert_redirected_to root_path
  end
end

class RegistrationRateLimitTest < ActionDispatch::IntegrationTest
  include RateLimitHelpers

  test "the eleventh sign up in three minutes is refused and creates nothing" do
    with_rate_limits do
      10.times { post registration_path, params: { user: { username: "ab" } } }
      assert_response 422

      assert_no_difference "User.count" do
        post registration_path, params: {
          user: { username: "fresh_user", email_address: "fresh@example.com",
                  password: "password123", password_confirmation: "password123" }
        }
      end
    end

    assert_redirected_to new_registration_path
    assert_equal "Try again later.", flash[:alert]
  end
end

class PasswordResetRateLimitTest < ActionDispatch::IntegrationTest
  include RateLimitHelpers

  test "the eleventh request for a reset link in three minutes is refused and sends nothing" do
    with_rate_limits do
      10.times { post passwords_path, params: { email_address: "nobody@example.com" } }
      assert_redirected_to new_session_path

      post passwords_path, params: { email_address: users(:one).email_address }
    end

    assert_redirected_to new_password_path
    assert_equal "Try again later.", flash[:alert]
    assert_enqueued_emails 0
  end

  test "the page with the form is not limited" do
    with_rate_limits do
      15.times { get new_password_path }
      post passwords_path, params: { email_address: users(:one).email_address }
    end

    assert_redirected_to new_session_path
    assert_enqueued_emails 1
  end
end

class OmniauthRateLimitTest < ActionDispatch::IntegrationTest
  include OmniauthHelpers
  include RateLimitHelpers

  test "the twenty-first return from a service in three minutes is refused" do
    mock_oauth(:github, uid: "900")

    with_rate_limits do
      20.times do
        sign_in_with(:github)
        assert_redirected_to new_oauth_signup_path
      end

      sign_in_with(:github)
    end

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
  end

  test "failed sign ins use the same count" do
    mock_oauth_failure(:github, :access_denied)

    with_rate_limits do
      20.times { get "/auth/failure", params: { message: "access_denied" } }
      assert_includes flash[:alert], "We could not sign you in"

      get "/auth/failure", params: { message: "access_denied" }
    end

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
  end
end

class OauthSignupRateLimitTest < ActionDispatch::IntegrationTest
  include OmniauthHelpers
  include RateLimitHelpers

  test "the eleventh try to finish signing up in three minutes is refused and creates nothing" do
    mock_oauth(:github, uid: "910", email: "limited@example.com")
    sign_in_with(:github)

    with_rate_limits do
      10.times { post oauth_signup_path, params: { user: { username: "ab" } } }
      assert_response 422

      assert_no_difference "User.count" do
        post oauth_signup_path, params: { user: { username: "chosen_name" } }
      end
    end

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
  end
end

class EmailVerificationRateLimitTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include RateLimitHelpers

  test "the thirty-first try or request for a code in ten minutes is refused, even with the right code" do
    person = create_unverified_user("limited_user")
    sign_in_as(person)

    with_rate_limits do
      # Only the first request sends an email, the others are held back by the one minute rule,
      # but every one of them is counted
      30.times { post resend_email_verification_path }
      code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]

      post email_verification_path, params: { otp: code }
    end

    assert_redirected_to email_verification_path
    assert_equal "Too many attempts. Please wait a few minutes.", flash[:alert]
    assert_not person.reload.email_verified?
  end

  test "the limit is counted per user" do
    first = create_unverified_user("first_limited")
    second = create_unverified_user("second_limited")

    with_rate_limits do
      sign_in_as(first)
      31.times { post resend_email_verification_path }
      assert_equal "Too many attempts. Please wait a few minutes.", flash[:alert]

      sign_in_as(second)
      post resend_email_verification_path
    end

    assert_includes flash[:notice], "We sent a new code"
  end
end

class AccountRateLimitTest < ActionDispatch::IntegrationTest
  include PostBuilder
  include RateLimitHelpers

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  def change_password(current: "nope")
    patch account_password_path, params: {
      user: { current_password: current, password: "new-password-123", password_confirmation: "new-password-123" }
    }
  end

  def ask_to_change_email(password: "wrong")
    post account_email_path, params: { email_address: "new-address@example.com", current_password: password }
  end

  test "the eleventh try to change the password in three minutes is refused, even with the right one" do
    with_rate_limits do
      10.times { change_password }
      assert_response 422

      change_password(current: "password")
    end

    assert_redirected_to edit_account_path
    assert_equal "Try again later.", flash[:alert]
    assert @user.reload.authenticate("password")
  end

  test "the fourth request for a link to set a password in ten minutes is refused and sends nothing" do
    person = create_oauth_user
    sign_in_as(person)

    with_rate_limits do
      3.times do
        post account_password_setup_path
        assert_equal "We emailed a link to o***@example.com.", flash[:notice]
      end

      assert_no_enqueued_emails do
        post account_password_setup_path
      end
    end

    assert_redirected_to edit_account_path
    assert_equal "Try again later.", flash[:alert]
  end

  test "the sixth request to change the email address in ten minutes is refused and sends nothing" do
    with_rate_limits do
      5.times do
        ask_to_change_email
        assert_equal "Current password is incorrect.", flash[:alert]
      end

      assert_no_difference "ActionMailer::Base.deliveries.size" do
        ask_to_change_email(password: "password")
      end
    end

    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal "Try again later.", flash[:alert]
    assert_nil EmailVerificationCode.current_for(@user)
  end

  test "the limits of the account page are counted separately" do
    with_rate_limits do
      6.times { ask_to_change_email }
      assert_equal "Try again later.", flash[:alert]

      change_password
    end

    assert_response 422
    assert_select "[role=alert] li", "Current password is incorrect"
  end
end
