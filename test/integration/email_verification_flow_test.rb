require "test_helper"
require "minitest/mock"
require_relative "../support/post_builder"

# The way from signing up to a verified account, from start to end
class EmailVerificationFlowTest < ActionDispatch::IntegrationTest
  include PostBuilder

  def sign_up(overrides = {})
    post registration_path, params: {
      user: { username: "flow_user", email_address: "flow@example.com",
              password: "password123", password_confirmation: "password123" }.merge(overrides)
    }
  end

  def emailed_code
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
  end

  def from_post_page(post)
    { "Referer" => "http://www.example.com#{post_page_path_for(post)}" }
  end

  # Signing up

  test "signing up emails a code to the new address, once" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      sign_up
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "flow@example.com" ], mail.to
    assert_match(/\A\d{6}\z/, emailed_code)

    user = User.find_by!(username: "flow_user")
    assert_equal :ok, EmailVerificationCode.current_for(user).check(emailed_code)
  end

  test "the verification page shows where the code was sent" do
    sign_up
    assert_redirected_to email_verification_path

    follow_redirect!

    assert_response :success
    assert_select ".alert-success span", "Welcome to Aalam! We sent a 6 digit code to f***@example.com."
    assert_select "strong", "f***@example.com"
    assert_select "input[name=otp]", 1
  end

  test "an account is made even when the email cannot be sent, and the next try works at once" do
    EmailVerificationMailer.stub(:code, ->(*) { raise "the mail server is down" }) do
      assert_difference "User.count", 1 do
        sign_up
      end
    end

    assert_redirected_to email_verification_path
    assert_includes flash[:alert], "could not send the code"
    assert_equal 0, EmailVerificationCode.count

    follow_redirect!
    assert_select "form[action=?] button", resend_email_verification_path, text: "Send me a code"

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post resend_email_verification_path
    end
    assert_equal "We sent a new code to f***@example.com.", flash[:notice]
  end

  test "a failed sign up sends no email" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      sign_up(username: "ab")
    end

    assert_response 422
  end

  # Logging in without a verified address

  test "logging in without a verified address leads to the verification page" do
    user = create_unverified_user("login_user")

    post session_path, params: { login: user.username, password: "password123" }

    assert_redirected_to email_verification_path
    assert cookies[:session_id]
  end

  test "the page the person wanted is kept until the address is verified" do
    user = create_unverified_user("login_user")

    get saved_posts_path
    assert_redirected_to new_session_path

    post session_path, params: { login: user.username, password: "password123" }
    assert_redirected_to email_verification_path

    _, code = EmailVerificationCode.issue(user)
    post email_verification_path, params: { otp: code }

    assert_redirected_to saved_posts_url
  end

  # The whole journey

  test "sign up, be stopped by the buttons, verify with the emailed code, then like" do
    post_to_like = create_post
    sign_up
    code = emailed_code

    post post_like_path(post_to_like), headers: from_post_page(post_to_like)
    assert_redirected_to email_verification_path
    assert_equal 0, post_to_like.reload.likes_count

    post email_verification_path, params: { otp: code }
    assert_redirected_to post_page_path_for(post_to_like)
    assert User.find_by!(username: "flow_user").email_verified?

    post post_like_path(post_to_like), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal 1, post_to_like.reload.likes_count

    get email_verification_path
    assert_redirected_to root_path
  end
end
