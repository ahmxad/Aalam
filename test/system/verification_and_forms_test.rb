require "application_system_test_case"

class VerificationAndFormsTest < ApplicationSystemTestCase
  PREVIEW = "img[alt='Selected profile picture preview']".freeze

  def sign_in_unverified(username = "browser_user")
    user = create_unverified_user(username)
    log_in_as(user, password: "password123")
    user
  end

  # The code box

  test "typing the sixth digit of the code verifies the address without pressing anything" do
    user = sign_in_unverified
    _, code = EmailVerificationCode.issue(user)

    visit email_verification_path
    wait_for_controller("otp-input")
    fill_in "otp", with: code

    assert_text "Your email is verified"
    assert user.reload.email_verified?
  end

  test "only digits can be typed in the code box" do
    user = sign_in_unverified
    EmailVerificationCode.issue(user)

    visit email_verification_path
    wait_for_controller("otp-input")
    fill_in "otp", with: "12ab 34"

    assert_field "otp", with: "1234"
    assert_no_text "That code is not right"
  end

  test "a wrong code is refused at once, with the tries that are left" do
    user = sign_in_unverified
    _, code = EmailVerificationCode.issue(user)
    wrong = (code.to_i + 1).to_s.rjust(6, "0")

    visit email_verification_path
    wait_for_controller("otp-input")
    fill_in "otp", with: wrong

    assert_text "That code is not right. You have 4 tries left."
    assert_not user.reload.email_verified?
  end

  # The sign up form

  test "the password meter rates what is typed, as it is typed" do
    visit signup_path
    wait_for_controller("password-strength")

    {
      "abc" => [ "Too short (at least 8 characters)", "progress-error" ],
      "password123" => [ "Weak password", "progress-error" ],
      # A capital letter does not rescue one of the most common passwords there is
      "Password123" => [ "Weak password", "progress-error" ],
      "Blue7Table" => [ "Fair password", "progress-warning" ],
      "Tr0ub4dor&3xyz" => [ "Strong password", "progress-success" ]
    }.each do |password, (label, bar)|
      fill_in "user[password]", with: password

      assert_selector "[data-password-strength-target=label]", text: label
      assert_selector "progress.#{bar}"
    end
  end

  test "a chosen picture is shown as a preview that the browser really loaded" do
    picture = uploaded_image(:jpeg, width: 60, height: 40)
    visit signup_path
    wait_for_controller("avatar-preview")

    attach_file "user[avatar_upload]", picture.path

    assert_selector PREVIEW, visible: :visible
    assert_text "will be converted to WebP automatically"
    # A preview that the Content Security Policy blocks is in the page, but never loads
    wait_for("the preview should have loaded") do
      evaluate_script("document.querySelector(\"#{PREVIEW}\").naturalWidth") > 0
    end
    assert_match(/\Ablob:/, find(PREVIEW)[:src])
  end

  test "a file that is not a picture is refused at once, with the reason" do
    notes = uploaded_file("some text", filename: "notes.txt", content_type: "text/plain")
    visit signup_path
    wait_for_controller("avatar-preview")

    attach_file "user[avatar_upload]", notes.path

    assert_text "is not supported. Choose a JPEG, PNG or WebP picture."
    assert_selector "input.file-input-error"
    assert_selector PREVIEW, visible: :hidden
  end

  # The whole way

  test "a person signs up with a picture and verifies the emailed code" do
    picture = uploaded_image(:png)
    visit signup_path
    wait_for_controller("avatar-preview")

    fill_in "user[username]", with: "journey_user"
    fill_in "user[email_address]", with: "journey@example.com"
    fill_in "user[password]", with: "Tr0ub4dor&3xyz"
    fill_in "user[password_confirmation]", with: "Tr0ub4dor&3xyz"
    attach_file "user[avatar_upload]", picture.path
    assert_text "will be converted to WebP automatically"
    click_button "Sign up"

    assert_current_path email_verification_path
    assert_text "We sent a 6 digit code to j***@example.com"

    wait_for_controller("otp-input")
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{6}\b/]
    fill_in "otp", with: code

    assert_text "Your email is verified"
    user = User.find_by!(username: "journey_user")
    assert user.email_verified?
    assert_equal "image/webp", user.avatar.content_type
  end
end
