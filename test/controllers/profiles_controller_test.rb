require "test_helper"
require_relative "../support/image_fixtures"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include ImageFixtures

  setup { @user = users(:one) }

  # Public access

  test "anyone can open a profile without signing in" do
    get profile_path(@user.username)

    assert_response :success
    assert_select "title", "#{@user.username} (@#{@user.username}) | Aalam"
    assert_select "main h1", "@#{@user.username}"
  end

  test "the username in the address is not case sensitive" do
    get profile_path(@user.username.upcase)

    assert_response :success
    assert_select "main h1", "@#{@user.username}"
  end

  test "an unknown username gives a 404" do
    get profile_path("nobody_here")

    assert_response :not_found
  end

  # What is shown

  test "the display name, bio and join date are shown when they exist" do
    @user.update!(display_name: "Shown Name", bio: "Writes about Rails.")

    get profile_path(@user.username)

    assert_select "title", "Shown Name (@#{@user.username}) | Aalam"
    assert_select "main p.font-semibold", "Shown Name"
    assert_select "main p", "Writes about Rails."
    assert_select "main p", "Joined #{I18n.l(@user.created_at.to_date, format: :long)}"
  end

  test "an empty display name and bio leave no empty lines" do
    get profile_path(@user.username)

    assert_select "main p.font-semibold", 0
    assert_select "main p.whitespace-pre-line", 0
    assert_select "main p", /Joined/
  end

  test "the email address is never shown" do
    get profile_path(@user.username)
    assert_not_includes response.body, @user.email_address

    sign_in_as(@user)
    get profile_path(@user.username)
    assert_not_includes response.body, @user.email_address
  end

  test "text written by the user is escaped" do
    @user.update!(display_name: "<b>Bold</b>", bio: "<script>alert(1)</script>")

    get profile_path(@user.username)

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_not_includes response.body, "<b>Bold</b>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  # Picture

  test "without a picture the first letter of the name is shown" do
    get profile_path(@user.username)

    assert_select "main .avatar-placeholder span", @user.public_name.first.upcase
    assert_select "main .avatar img", 0
  end

  test "with a picture the picture is shown" do
    @user.avatar_upload = uploaded_image(:jpeg)
    @user.save!

    get profile_path(@user.username)

    assert_select "main .avatar img[alt=?]", "#{@user.public_name} profile picture"
    assert_select "main .avatar-placeholder", 0
  end

  # Edit button

  test "the owner sees the edit button" do
    sign_in_as(@user)

    get profile_path(@user.username)

    assert_select "main a[href=?]", edit_account_path, text: "Edit profile"
  end

  test "other people do not see the edit button" do
    get profile_path(@user.username)
    assert_select "main a[href=?]", edit_account_path, 0

    sign_in_as(users(:two))
    get profile_path(@user.username)
    assert_select "main a[href=?]", edit_account_path, 0
  end
end
