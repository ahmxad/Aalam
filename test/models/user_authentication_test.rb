require "test_helper"

class UserAuthenticationTest < ActiveSupport::TestCase
  def create_user(username, **attributes)
    User.create!({ username: username, email_address: "#{username}@example.com", password: "password123" }.merge(attributes))
  end

  # Email verification

  test "a new user starts with an unverified email address and a known password" do
    user = create_user("fresh_one")

    assert_not user.email_verified?
    assert user.password_set?
  end

  test "verify_email! marks the address as verified" do
    user = create_user("fresh_two")

    user.verify_email!

    assert user.reload.email_verified?
    assert_in_delta Time.current.to_f, user.email_verified_at.to_f, 5
  end

  test "the users in the fixtures are verified" do
    assert users(:one).email_verified?
    assert users(:two).email_verified?
  end

  # Ways to sign in

  test "with a password every connected service can be disconnected" do
    user = create_user("has_password")
    identity = user.identities.create!(provider: "github", uid: "1")

    assert user.can_disconnect?(identity)
  end

  test "without a password the only connected service cannot be disconnected" do
    user = create_user("no_password", password_set: false)
    github = user.identities.create!(provider: "github", uid: "1")

    assert_not user.can_disconnect?(github)
  end

  test "without a password a service can go when another one stays" do
    user = create_user("two_services", password_set: false)
    github = user.identities.create!(provider: "github", uid: "1")
    google = user.identities.create!(provider: "google_oauth2", uid: "2")

    assert user.can_disconnect?(github)
    assert user.can_disconnect?(google)
  end

  test "setting a password marks it as set, and other changes do not" do
    user = create_user("no_password", password_set: false)

    user.update!(display_name: "Name only")
    assert_not user.reload.password_set?

    user.update!(password: "new-password-123")
    assert user.reload.password_set?
  end

  # Suggesting a username

  test "suggest_username turns text into a valid username" do
    {
      "John Doe" => "john_doe",
      "ahmxad" => "ahmxad",
      "j.doe@home" => "j_doe_home",
      "  --weird--  " => "weird",
      "ünïcode" => "n_code",
      ("a" * 30) => ("a" * 16)
    }.each do |text, expected|
      assert_equal expected, User.suggest_username(text), text.inspect
    end
  end

  test "suggest_username falls back to user when nothing usable is left" do
    [ nil, "", "ab", "!!", "你好" ].each do |text|
      assert_equal "user", User.suggest_username(text), text.inspect
    end
  end

  test "suggest_username adds a number when the name is taken or reserved" do
    assert_equal "user_one2", User.suggest_username("user_one")
    assert_equal "admin2", User.suggest_username("admin")

    create_user("john_doe")
    create_user("john_doe2")
    assert_equal "john_doe3", User.suggest_username("John Doe")
  end

  test "suggested usernames always pass the username rules" do
    [ "John Doe", "a" * 30, "ünïcode", "admin", nil, "user_one" ].each do |text|
      assert_match(/\A[a-z0-9_]{3,20}\z/, User.suggest_username(text), text.inspect)
    end
  end

  # Cleaning up

  test "deleting a user deletes their connected services and codes" do
    user = create_user("leaving_soon")
    user.identities.create!(provider: "github", uid: "99")
    EmailVerificationCode.issue(user)

    assert_difference [ "Identity.count", "EmailVerificationCode.count" ], -1 do
      user.destroy
    end
  end
end
