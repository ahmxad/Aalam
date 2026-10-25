require "test_helper"
require_relative "../support/image_fixtures"

class AccountsAccessTest < ActionDispatch::IntegrationTest
  test "every account action needs a signed in user and changes nothing" do
    assert_no_changes -> { users(:one).reload.attributes.slice("display_name", "password_digest") } do
      get edit_account_path
      assert_redirected_to new_session_path

      patch account_path, params: { user: { display_name: "Hacked" } }
      assert_redirected_to new_session_path

      patch account_password_path, params: {
        user: { current_password: "password", password: "new-password-123", password_confirmation: "new-password-123" }
      }
      assert_redirected_to new_session_path

      delete account_avatar_path
      assert_redirected_to new_session_path
    end
  end
end

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include ImageFixtures

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  def change_password(overrides = {})
    patch account_password_path, params: {
      user: { current_password: "password", password: "new-password-123", password_confirmation: "new-password-123" }.merge(overrides)
    }
  end

  # The page

  test "edit shows the profile form and the password form" do
    get edit_account_path

    assert_response :success
    assert_select "h1", "Account settings"
    assert_select "a[href=?]", profile_path(@user.username), text: "Back to profile"

    assert_select "form[action=?][enctype='multipart/form-data']", account_path do
      assert_select "input[name='user[username]'][value=?]", @user.username
      assert_select "input[name='user[display_name]']"
      assert_select "textarea[name='user[bio]']"
      assert_select "input[name='user[avatar_upload]'][type=file]"
      assert_select "input[type=email][disabled][value=?]", @user.email_address
    end

    assert_select "form[action=?]", account_password_path do
      assert_select "input[name='user[current_password]'][type=password]"
      assert_select "input[name='user[password]'][type=password]"
      assert_select "input[name='user[password_confirmation]'][type=password]"
    end
  end

  test "edit attaches the live helpers" do
    get edit_account_path

    assert_select "[data-controller='username-availability'][data-username-availability-url-value=?]", username_availability_path
    assert_select "[data-controller='avatar-preview']"
  end

  # Profile

  test "update saves the profile and shows the profile page" do
    patch account_path, params: { user: { username: "Renamed_User", display_name: "  New Name ", bio: "Hello there" } }

    assert_redirected_to profile_path("renamed_user")
    assert_equal "Profile updated.", flash[:notice]

    @user.reload
    assert_equal "renamed_user", @user.username
    assert_equal "New Name", @user.display_name
    assert_equal "Hello there", @user.bio
  end

  test "update keeps the username when it is not changed" do
    patch account_path, params: { user: { username: @user.username, display_name: "Same Username" } }

    assert_redirected_to profile_path(@user.username)
    assert_equal "Same Username", @user.reload.display_name
  end

  test "update turns blank optional fields into nothing" do
    @user.update!(display_name: "Had A Name", bio: "Had a bio")

    patch account_path, params: { user: { display_name: "  ", bio: "" } }

    assert_nil @user.reload.display_name
    assert_nil @user.bio
  end

  test "update with a taken username shows an error and changes nothing" do
    patch account_path, params: { user: { username: users(:two).username, display_name: "Nope" } }

    assert_response 422
    assert_select "[role=alert] li", "Username has already been taken"
    assert_not_equal users(:two).username, @user.reload.username
    assert_nil @user.display_name
  end

  test "update with invalid values shows the matching error" do
    {
      { username: "ab" } => "Username is too short (minimum is 3 characters)",
      { username: "bad name" } => "Username can only contain letters, numbers and underscores",
      { username: "admin" } => "Username is not available",
      { display_name: "a" * 51 } => "Display name is too long (maximum is 50 characters)",
      { bio: "a" * 161 } => "Bio is too long (maximum is 160 characters)"
    }.each do |overrides, message|
      patch account_path, params: { user: { username: @user.username }.merge(overrides) }

      assert_response 422
      assert_select "[role=alert] li", message
    end
  end

  test "the back link still points to the saved username after a failed update" do
    patch account_path, params: { user: { username: "ab" } }

    assert_response 422
    assert_select "a[href=?]", profile_path(@user.username), text: "Back to profile"
  end

  test "a failed update leaves the navbar showing the saved values" do
    patch account_path, params: { user: { username: "bad name", display_name: "Unsaved Name" } }

    assert_response 422
    assert_select "header .dropdown-content p.font-semibold", @user.public_name
    assert_select "header .dropdown-content a[href=?]", profile_path(@user.username), text: "Profile"
  end

  test "update cannot change the email address or make the user an admin" do
    patch account_path, params: { user: { display_name: "Still Me", email_address: "hacked@example.com", admin: "true" } }

    @user.reload
    assert_equal "Still Me", @user.display_name
    assert_equal "one@example.com", @user.email_address
    assert_not @user.admin?
  end

  # Picture

  test "update with a picture stores it as a WebP" do
    patch account_path, params: { user: { avatar_upload: uploaded_image(:png, filename: "me.png") } }

    assert_redirected_to profile_path(@user.username)
    assert @user.reload.avatar_stored?
    assert_equal "image/webp", @user.avatar.content_type
  end

  test "update with a file that is not an image shows an error" do
    not_an_image = uploaded_file("not an image", filename: "me.jpg", content_type: "image/jpeg")

    patch account_path, params: { user: { avatar_upload: not_an_image } }

    assert_response 422
    assert_select "[role=alert] li", "Avatar must be a JPEG, PNG or WebP"
    assert_not @user.reload.avatar.attached?
  end

  test "update without a new file keeps the current picture" do
    @user.avatar_upload = uploaded_image(:jpeg)
    @user.save!

    patch account_path, params: { user: { bio: "Only the bio changed" } }

    assert_redirected_to profile_path(@user.username)
    assert @user.reload.avatar_stored?
  end

  test "update with a scalar avatar shows a validation error" do
    patch account_path, params: { user: { avatar_upload: "not a file", display_name: "Unsaved Name" } }

    assert_response 422
    assert_select "[role=alert] li", "Avatar must be a JPEG, PNG or WebP"
    assert_nil @user.reload.display_name
    assert_not @user.avatar.attached?
  end

  test "the remove button only shows when there is a picture" do
    get edit_account_path
    assert_select "form[action=?]", account_avatar_path, 0

    @user.avatar_upload = uploaded_image(:jpeg)
    @user.save!

    get edit_account_path
    assert_select "form[action=?] button", account_avatar_path, text: "Remove picture"
  end

  test "destroy_avatar removes the picture" do
    @user.avatar_upload = uploaded_image(:jpeg)
    @user.save!

    delete account_avatar_path

    assert_redirected_to edit_account_path
    assert_equal "Profile picture removed.", flash[:notice]
    assert_not User.find(@user.id).avatar.attached?
  end

  test "destroy_avatar without a picture is harmless" do
    delete account_avatar_path

    assert_redirected_to edit_account_path
  end

  test "destroy_avatar only touches the signed in user" do
    other = users(:two)
    other.avatar_upload = uploaded_image(:jpeg)
    other.save!

    delete account_avatar_path

    assert User.find(other.id).avatar_stored?
  end

  # Password

  test "changing the password works and the new password can be used" do
    change_password

    assert_redirected_to edit_account_path
    assert_equal "Password updated.", flash[:notice]

    @user.reload
    assert @user.authenticate("new-password-123")
    assert_not @user.authenticate("password")
  end

  test "changing the password signs out the other devices but not this one" do
    @user.sessions.create!(user_agent: "Other phone", ip_address: "10.0.0.2")

    assert_difference -> { @user.sessions.count }, -1 do
      change_password
    end

    get edit_account_path
    assert_response :success
  end

  test "a wrong current password changes nothing" do
    assert_no_changes -> { @user.reload.password_digest } do
      change_password(current_password: "not-my-password")
    end

    assert_response 422
    assert_select "[role=alert] li", "Current password is incorrect"
  end

  test "a blank new password changes nothing" do
    assert_no_changes -> { @user.reload.password_digest } do
      change_password(password: "", password_confirmation: "")
    end

    assert_response 422
    assert_select "[role=alert] li", "New password can't be blank"
  end

  test "a too short new password changes nothing" do
    assert_no_changes -> { @user.reload.password_digest } do
      change_password(password: "short", password_confirmation: "short")
    end

    assert_response 422
    assert_select "[role=alert] li", "Password is too short (minimum is 8 characters)"
  end

  test "a new password that does not match its confirmation changes nothing" do
    assert_no_changes -> { @user.reload.password_digest } do
      change_password(password_confirmation: "other-password-456")
    end

    assert_response 422
    assert_select "[role=alert] li", "Password confirmation doesn't match Password"
  end
end
