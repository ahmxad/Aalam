require "test_helper"
require "minitest/mock"
require_relative "../support/post_builder"

class EmailVerificationsAccessTest < ActionDispatch::IntegrationTest
  test "every action needs a signed in user" do
    get email_verification_path
    assert_redirected_to new_session_path

    post email_verification_path, params: { otp: "123456" }
    assert_redirected_to new_session_path

    post resend_email_verification_path
    assert_redirected_to new_session_path

    delete email_verification_path
    assert_redirected_to new_session_path
  end

  test "a visitor who is not signed in cannot make the site send an email" do
    assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
      post resend_email_verification_path
    end
  end
end

class EmailVerificationsShowTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @user = create_unverified_user("show_user")
    sign_in_as(@user)
  end

  test "without a code the page offers to send one and shows no code box" do
    get email_verification_path

    assert_response :success
    assert_select "h1", "Verify your email"
    assert_select "strong", "s***@example.com"
    assert_select "form[action=?] button", resend_email_verification_path, text: "Send me a code"
    assert_select "input[name=otp]", 0
  end

  test "with a code the page shows the box for it" do
    EmailVerificationCode.issue(@user)

    get email_verification_path

    assert_select "p", /We sent a 6 digit code to/
    assert_select "p", /expires in 10 minutes/
    assert_select "input[name=otp][inputmode=numeric][autocomplete=one-time-code][data-controller=otp-input]"
    assert_select "form[action=?] input[type=submit][value=?]", email_verification_path, "Verify email"
    assert_select "form[action=?] button", resend_email_verification_path, text: "Send a new code"
  end

  test "opening the page sends nothing" do
    assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
      get email_verification_path
    end
  end

  test "an unverified user can go and fix a wrong address" do
    get email_verification_path

    assert_select "a[href=?]", edit_account_path(anchor: "email"), text: "Change it"
    assert_select "button", text: "Cancel the change", count: 0
  end

  test "a user whose address is verified has nothing to do on this page" do
    sign_in_as(users(:one))

    get email_verification_path

    assert_redirected_to root_path
    assert_equal "Your email is already verified.", flash[:notice]
  end
end

class EmailVerificationsPendingChangeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @record, @code = EmailVerificationCode.issue(@user, email: "new-address@example.com")
  end

  test "the page is about the new address and offers to cancel the change" do
    get email_verification_path

    assert_response :success
    assert_select "h1", "Confirm your new email"
    assert_select "strong", "n***@example.com"
    assert_select "input[type=submit][value=?]", "Confirm new email"
    assert_select "form[action=?] input[name=_method][value=delete]", email_verification_path
    assert_select "button", text: "Cancel the change"
    assert_select "a", text: "Change it", count: 0
    assert_select "p", /keeps using o\*\*\*@example\.com/
  end
end

class EmailVerificationsCreateTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @user = create_unverified_user("create_user")
    sign_in_as(@user)
    @record, @code = EmailVerificationCode.issue(@user)
  end

  def wrong_code
    (@code.to_i + 1).to_s.rjust(6, "0")
  end

  def submit(code)
    post email_verification_path, params: { otp: code }
  end

  test "the right code verifies the address" do
    submit(@code)

    assert_redirected_to root_path
    assert_equal "Your email is verified. Welcome aboard!", flash[:notice]
    assert @user.reload.email_verified?
    assert_not_nil @record.reload.consumed_at
  end

  test "only the digits of what was typed count" do
    submit(" #{@code[0, 3]}-#{@code[3, 3]} ")

    assert_redirected_to root_path
    assert @user.reload.email_verified?
  end

  test "a wrong code is refused and the tries left are shown" do
    submit(wrong_code)

    assert_response 422
    assert_select ".alert-error span", "That code is not right. You have 4 tries left."
    assert_select "input[name=otp]", 1
    assert_not @user.reload.email_verified?
    assert_equal 1, @record.reload.attempts
  end

  test "an empty code is a wrong code" do
    submit("")

    assert_response 422
    assert_select ".alert-error span", /That code is not right/
    assert_not @user.reload.email_verified?
  end

  test "five wrong tries lock the code, even for the right one afterwards" do
    5.times { submit(wrong_code) }
    assert_response 422
    assert_select ".alert-error span", "Too many wrong tries. Ask for a new code."

    submit(@code)

    assert_response 422
    assert_select ".alert-error span", "Too many wrong tries. Ask for a new code."
    assert_not @user.reload.email_verified?
  end

  test "an expired code is refused and the page offers a new one" do
    travel EmailVerificationCode::EXPIRES_IN + 1.minute

    submit(@code)

    assert_response 422
    assert_select ".alert-error span", "That code has expired. Ask for a new code."
    assert_select "form[action=?] button", resend_email_verification_path, text: "Send me a code"
    assert_select "input[name=otp]", 0
    assert_not @user.reload.email_verified?
  end

  test "without any code a typed code is treated as expired" do
    EmailVerificationCode.where(user: @user).delete_all

    submit("123456")

    assert_response 422
    assert_select ".alert-error span", "That code has expired. Ask for a new code."
  end

  test "a code works only once, and then there is nothing left to verify" do
    submit(@code)

    submit(@code)

    assert_redirected_to root_path
    assert_equal "Your email is already verified.", flash[:notice]
  end

  test "a code that was replaced by a newer one no longer works" do
    travel EmailVerificationCode::RESEND_AFTER + 1.second
    _, newer = EmailVerificationCode.issue(@user)

    submit(@code)
    assert_response 422
    assert_not @user.reload.email_verified?

    submit(newer)
    assert_redirected_to root_path
    assert @user.reload.email_verified?
  end
end

class EmailVerificationsResendTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @user = create_unverified_user("resend_user")
    sign_in_as(@user)
  end

  test "resend emails a code to the address of the account" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post resend_email_verification_path
    end

    assert_redirected_to email_verification_path
    assert_equal "We sent a new code to r***@example.com.", flash[:notice]
    assert_equal [ @user.email_address ], ActionMailer::Base.deliveries.last.to
    assert EmailVerificationCode.current_for(@user)
  end

  test "the emailed code is the one that verifies" do
    post resend_email_verification_path
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]

    post email_verification_path, params: { otp: code }

    assert_redirected_to root_path
    assert @user.reload.email_verified?
  end

  test "asking again at once is refused and sends nothing" do
    post resend_email_verification_path

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      post resend_email_verification_path
    end

    assert_redirected_to email_verification_path
    assert_match(/\APlease wait .+ before asking for another code\.\z/, flash[:alert])
  end

  test "after a minute a new code is sent and the old one stops working" do
    post resend_email_verification_path
    old_code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
    travel EmailVerificationCode::RESEND_AFTER + 1.second

    post resend_email_verification_path
    assert_equal 2, ActionMailer::Base.deliveries.size

    # The old code could, by bad luck, equal the new one, so the check is skipped in that case
    new_code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
    unless new_code == old_code
      post email_verification_path, params: { otp: old_code }
      assert_response 422
    end
  end

  test "a failed delivery says so, and the next try is not held back" do
    EmailVerificationMailer.stub(:code, ->(*) { raise "the mail server is down" }) do
      post resend_email_verification_path
    end

    assert_redirected_to email_verification_path
    assert_equal "We could not send the email. Please try again in a minute.", flash[:alert]
    assert_nil EmailVerificationCode.current_for(@user)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post resend_email_verification_path
    end
  end

  test "a code for a new address is sent to that address again" do
    user = users(:one)
    sign_in_as(user)
    EmailVerificationCode.issue(user, email: "new-address@example.com")
    travel EmailVerificationCode::RESEND_AFTER + 1.second

    post resend_email_verification_path

    assert_equal [ "new-address@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "We sent a new code to n***@example.com.", flash[:notice]
  end
end

class EmailVerificationsCancelTest < ActionDispatch::IntegrationTest
  include PostBuilder

  test "cancelling a waiting email change drops the code and keeps the address" do
    user = users(:one)
    sign_in_as(user)
    EmailVerificationCode.issue(user, email: "new-address@example.com")

    delete email_verification_path

    assert_response :see_other
    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal "The email change was cancelled.", flash[:notice]
    assert_nil EmailVerificationCode.current_for(user)
    assert_equal "one@example.com", user.reload.email_address
  end

  test "an unverified user cannot cancel the code for their own address" do
    user = create_unverified_user("cancel_user")
    sign_in_as(user)
    EmailVerificationCode.issue(user)

    delete email_verification_path

    assert_response :see_other
    assert_redirected_to email_verification_path
    assert EmailVerificationCode.current_for(user)
  end

  test "a verified user with nothing waiting is sent away" do
    sign_in_as(users(:one))

    delete email_verification_path

    assert_redirected_to root_path
  end
end

class EmailChangeConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @record, @code = EmailVerificationCode.issue(@user, email: "new-address@example.com")
  end

  def confirm(code)
    post email_verification_path, params: { otp: code }
  end

  test "the right code makes the new address the address of the account" do
    confirm(@code)

    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal "Your email address is now new-address@example.com.", flash[:notice]

    @user.reload
    assert_equal "new-address@example.com", @user.email_address
    assert @user.email_verified?
    assert_in_delta Time.current.to_f, @user.email_verified_at.to_f, 5
  end

  test "the old address is told about the change" do
    confirm(@code)

    assert_enqueued_email_with EmailChangeMailer, :notice, args: [ @user, "one@example.com" ]
  end

  test "the other devices are signed out and this one stays signed in" do
    other = @user.sessions.create!(user_agent: "Other phone", ip_address: "10.0.0.2")

    confirm(@code)

    assert_not Session.exists?(other.id)
    assert_equal 1, @user.sessions.count

    get edit_account_path
    assert_response :success
  end

  test "a wrong code changes nothing" do
    confirm((@code.to_i + 1).to_s.rjust(6, "0"))

    assert_response 422
    assert_select ".alert-error span", /That code is not right/
    assert_select "h1", "Confirm your new email"
    assert_equal "one@example.com", @user.reload.email_address
    assert_enqueued_emails 0
  end

  test "an address that someone else took in the meantime is refused" do
    users(:two).update_columns(email_address: "new-address@example.com")

    confirm(@code)

    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal "That did not work out. Please start the email change again.", flash[:alert]
    assert_equal "one@example.com", @user.reload.email_address
    assert_enqueued_emails 0
  end
end
