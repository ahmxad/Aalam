require "test_helper"
require "minitest/mock"
require_relative "../support/post_builder"

class EmailSectionTest < ActionDispatch::IntegrationTest
  include PostBuilder

  test "a verified user sees the address, a Verified badge and the form for changing it" do
    sign_in_as(users(:one))

    get edit_account_path

    assert_select "section#email h2", "Email address"
    assert_select "section#email strong", "one@example.com"
    assert_select "section#email .badge-success", "Verified"
    assert_select "section#email .badge-warning", 0
    assert_select "section#email form[action=?]", account_email_path do
      assert_select "input[name=email_address][type=email]"
      assert_select "input[name=current_password][type=password]"
      assert_select "input[type=submit][value=?]", "Send a code to the new address"
    end
  end

  test "an unverified user sees the Not verified badge and still has to give the password" do
    sign_in_as(create_unverified_user("unverified_one"))

    get edit_account_path

    assert_select "section#email .badge-warning", "Not verified"
    assert_select "section#email .badge-success", 0
    assert_select "section#email input[name=current_password]", 1
  end

  test "a user without a password who has a verified address is told to set one first" do
    sign_in_as(create_oauth_user)

    get edit_account_path

    assert_select "section#email form", 0
    assert_select "section#email p", "To change your email address, first set a password below."
  end

  test "a user without a password whose address is not verified can fix it, with no password asked" do
    sign_in_as(create_oauth_user("unverified_oauth", verified: false))

    get edit_account_path

    assert_select "section#email form[action=?]", account_email_path
    assert_select "section#email input[name=current_password]", 0
  end

  test "a change that waits for its code is shown, with a link to enter the code" do
    user = users(:one)
    sign_in_as(user)
    EmailVerificationCode.issue(user, email: "new-address@example.com")

    get edit_account_path

    assert_select "section#email p", /Waiting for you to confirm\s+new-address@example\.com/
    assert_select "section#email a[href=?]", email_verification_path, text: "Enter the code"
  end

  test "nothing is shown as waiting when no change was asked for" do
    sign_in_as(users(:one))

    get edit_account_path

    assert_select "section#email a", 0
    assert_not_includes response.body, "Waiting for you to confirm"
  end

  test "the code for the address the account already has is not shown as a change" do
    person = create_unverified_user("signup_user")
    sign_in_as(person)
    EmailVerificationCode.issue(person)

    get edit_account_path

    assert_select "section#email a[href=?]", email_verification_path, 0
  end
end

class EmailChangeRequestTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  def ask_for_change(address, password: "password", **extra)
    post account_email_path, params: { email_address: address, current_password: password }.merge(extra)
  end

  def emailed_code
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
  end

  def assert_refused_with(message)
    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal message, flash[:alert]
  end

  # Who can ask

  test "a visitor who is not signed in is sent to log in and nothing is emailed" do
    delete session_path

    assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
      ask_for_change("new-address@example.com")
    end

    assert_redirected_to new_session_path
  end

  # Asking

  test "a code is sent to the new address and the account keeps the old one until it is typed in" do
    assert_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ], 1 do
      ask_for_change("new-address@example.com")
    end

    assert_redirected_to email_verification_path
    assert_equal "We sent a 6 digit code to n***@example.com. Enter it to confirm the change.", flash[:notice]
    assert_equal [ "new-address@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "new-address@example.com", EmailVerificationCode.current_for(@user).email

    @user.reload
    assert_equal "one@example.com", @user.email_address
    assert @user.email_verified?
  end

  test "the new address is tidied up" do
    ask_for_change("  New-Address@Example.COM ")

    assert_equal [ "new-address@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "new-address@example.com", EmailVerificationCode.current_for(@user).email
  end

  # What is refused

  test "a wrong password is refused and nothing is sent" do
    assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
      ask_for_change("new-address@example.com", password: "not-my-password")
    end

    assert_refused_with "Current password is incorrect."
  end

  test "a request without a password is refused too" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      post account_email_path, params: { email_address: "new-address@example.com" }
    end

    assert_refused_with "Current password is incorrect."
  end

  test "the address the account already has is refused, whatever its letter case" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      ask_for_change("ONE@example.com")
    end

    assert_refused_with "That is already your email address."
  end

  test "an address that another account uses is refused" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      ask_for_change(users(:two).email_address)
    end

    assert_refused_with "Email address has already been taken."
  end

  test "an address that is blank or not an address is refused" do
    {
      "" => "Email address can't be blank.",
      "not-an-email" => "Email address is invalid."
    }.each do |address, message|
      assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
        ask_for_change(address)
      end

      assert_refused_with message
    end
  end

  test "asking again at once is refused and sends nothing more" do
    ask_for_change("first-new@example.com")

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      ask_for_change("second-new@example.com")
    end

    assert_redirected_to edit_account_path(anchor: "email")
    assert_match(/\APlease wait .+ before asking for another code\.\z/, flash[:alert])
  end

  test "an email that cannot be sent is reported, and the next try is not held back" do
    EmailVerificationMailer.stub(:code, ->(*) { raise "the mail server is down" }) do
      ask_for_change("new-address@example.com")
    end

    assert_refused_with "We could not send the email. Please try again in a minute."
    assert_nil EmailVerificationCode.current_for(@user)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      ask_for_change("new-address@example.com")
    end
  end

  # Without a password

  test "a user without a password and with a verified address must set a password first" do
    person = create_oauth_user
    sign_in_as(person)

    assert_no_difference [ "ActionMailer::Base.deliveries.size", "EmailVerificationCode.count" ] do
      post account_email_path, params: { email_address: "new-address@example.com" }
    end

    assert_refused_with "Set a password first, then you can change your email address."
  end

  test "a user without a password whose address was never verified can correct it" do
    person = create_oauth_user("unverified_oauth", verified: false)
    sign_in_as(person)

    post account_email_path, params: { email_address: "typed@example.com" }
    assert_redirected_to email_verification_path

    post email_verification_path, params: { otp: emailed_code }

    person.reload
    assert_equal "typed@example.com", person.email_address
    assert person.email_verified?
    assert_redirected_to edit_account_path(anchor: "email")
  end

  # Fixing a wrong address after signing up

  test "an unverified user fixes a wrong address with the password, and it becomes verified" do
    person = create_unverified_user("typo_user")
    sign_in_as(person)

    ask_for_change("right-address@example.com", password: "wrong-password")
    assert_refused_with "Current password is incorrect."

    ask_for_change("right-address@example.com", password: "password123")
    assert_redirected_to email_verification_path
    assert_equal [ "right-address@example.com" ], ActionMailer::Base.deliveries.last.to

    post email_verification_path, params: { otp: emailed_code }

    assert_redirected_to edit_account_path(anchor: "email")
    person.reload
    assert_equal "right-address@example.com", person.email_address
    assert person.email_verified?
  end

  # The whole way

  test "asking, typing the code, and then signing in with the new address only" do
    ask_for_change("new-address@example.com")
    post email_verification_path, params: { otp: emailed_code }

    assert_redirected_to edit_account_path(anchor: "email")
    assert_equal "Your email address is now new-address@example.com.", flash[:notice]
    assert_enqueued_email_with EmailChangeMailer, :notice, args: [ @user, "one@example.com" ]

    delete session_path

    post session_path, params: { login: "one@example.com", password: "password" }
    assert_redirected_to new_session_path

    post session_path, params: { login: "new-address@example.com", password: "password" }
    assert_redirected_to root_path
  end
end
