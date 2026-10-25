require "test_helper"
require_relative "../support/image_fixtures"

class UserProfileTest < ActiveSupport::TestCase
  include ImageFixtures

  def build_user(attributes = {})
    User.new({ username: "new_user", email_address: "new@example.com", password: "password123" }.merge(attributes))
  end

  test "a complete user is valid and is not an admin" do
    user = build_user

    assert user.valid?
    assert_not user.admin?
  end

  # Username

  test "username is required" do
    user = build_user(username: "")

    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "username is saved in lowercase without surrounding spaces" do
    assert_equal "mixed_case", build_user(username: "  Mixed_Case ").username
  end

  test "username must be unique, ignoring case" do
    user = build_user(username: users(:one).username.upcase)

    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "username must be between 3 and 20 characters" do
    assert_not build_user(username: "ab").valid?
    assert_not build_user(username: "a" * 21).valid?
    assert build_user(username: "abc").valid?
    assert build_user(username: "a" * 20).valid?
  end

  test "username allows only letters, numbers and underscores" do
    [ "john doe", "john.doe", "john-doe", "john!", "ahmad@home", "ünïcode" ].each do |name|
      assert_not build_user(username: name).valid?, "#{name.inspect} should be rejected"
    end

    [ "john_doe", "j0hn_99", "_underscore_" ].each do |name|
      assert build_user(username: name).valid?, "#{name.inspect} should be accepted"
    end
  end

  test "reserved usernames are not available" do
    %w[admin administrator root support aalam system].each do |name|
      user = build_user(username: name)

      assert_not user.valid?, "#{name} should be reserved"
      assert_includes user.errors[:username], "is not available"
    end
  end
  test "an admin may use a reserved username, other people may not" do
    assert build_user(username: "admin", admin: true).valid?
    assert_not build_user(username: "admin", admin: false).valid?
  end

  # Email and password

  test "email address must be valid and unique" do
    assert_not build_user(email_address: "not-an-email").valid?
    assert_not build_user(email_address: users(:one).email_address).valid?
  end

  test "password needs at least 8 characters" do
    user = build_user(password: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "an existing user can be updated without giving the password again" do
    assert users(:one).update(display_name: "Updated Name")
  end

  # Display name and bio

  test "display name and bio are optional and blank values are stored as nil" do
    user = build_user(display_name: "   ", bio: "")

    assert user.valid?
    assert_nil user.display_name
    assert_nil user.bio
  end

  test "display name is limited to 50 characters" do
    assert build_user(display_name: "a" * 50).valid?
    assert_not build_user(display_name: "a" * 51).valid?
  end

  test "bio is limited to 160 characters" do
    assert build_user(bio: "a" * 160).valid?
    assert_not build_user(bio: "a" * 161).valid?
  end

  test "public name is the display name, or the username when there is none" do
    assert_equal "new_user", build_user.public_name
    assert_equal "Shown Name", build_user(display_name: "Shown Name").public_name
  end

  # Avatar

  test "a chosen JPEG is stored as a WebP avatar" do
    user = build_user
    user.avatar_upload = uploaded_image(:jpeg)

    assert_not user.avatar_stored?
    assert user.save, user.errors.full_messages.to_sentence
    assert user.avatar_stored?
    assert_equal "image/webp", user.avatar.content_type
    assert_equal "avatar.webp", user.avatar.filename.to_s
  end

  test "an empty file field does nothing" do
    user = build_user
    user.avatar_upload = ""

    assert user.valid?
    assert_not user.avatar.attached?
  end

  test "a file that is not an image is rejected" do
    user = build_user
    user.avatar_upload = uploaded_file("this is not an image", filename: "avatar.jpg", content_type: "image/jpeg")

    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be a JPEG, PNG or WebP"
    assert_not user.avatar.attached?
  end

  test "a picture over 10 MB is rejected" do
    user = build_user
    user.avatar_upload = uploaded_file("a" * 11.megabytes, filename: "huge.jpg", content_type: "image/jpeg")

    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be smaller than 10 MB"
  end

  test "choosing a good picture after a bad one clears the error" do
    user = build_user
    user.avatar_upload = uploaded_file("nope", filename: "avatar.jpg", content_type: "image/jpeg")
    user.avatar_upload = uploaded_image(:png)

    assert user.valid?, user.errors.full_messages.to_sentence
  end
end
