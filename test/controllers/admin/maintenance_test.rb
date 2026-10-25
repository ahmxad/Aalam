require "test_helper"

class Admin::MaintenanceTest < ActionDispatch::IntegrationTest
  def old_unused_blob(name = "orphan.png")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/test.png"))),
      filename: name,
      content_type: "image/png"
    )
    blob.update_columns(created_at: 3.days.ago)
    blob
  end

  def sign_in_admin
    sign_in_as(User.create!(username: "maintenance_admin", email_address: "maintenance@test.com", password: "password123!", admin: true))
  end

  test "a guest cannot delete unused images" do
    blob = old_unused_blob

    post admin_purge_unused_images_url

    assert_redirected_to new_session_url
    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "a signed in non-admin cannot delete unused images" do
    sign_in_as(users(:one))
    blob = old_unused_blob

    post admin_purge_unused_images_url

    assert_redirected_to root_url
    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "an admin deletes the unused images and is told how many" do
    sign_in_admin
    blob = old_unused_blob

    post admin_purge_unused_images_url

    assert_redirected_to admin_root_url
    assert_not ActiveStorage::Blob.exists?(blob.id)

    follow_redirect!
    assert_select ".notice", text: /Deleted 1 unused image/
  end

  test "an admin is told when there is nothing to delete" do
    sign_in_admin

    post admin_purge_unused_images_url
    follow_redirect!

    assert_select ".notice", text: /no unused images/
  end

  test "images that belong to a post are never deleted" do
    sign_in_admin
    blob = old_unused_blob("kept.png")
    admin_posts(:one).images.attach(blob)

    post admin_purge_unused_images_url

    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "the dashboard shows how many unused images can be deleted" do
    sign_in_admin
    old_unused_blob

    get admin_root_url

    assert_response :success
    assert_select "strong", text: "1 unused image"
  end
end
