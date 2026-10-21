require "test_helper"

class DirectUploadsTest < ActionDispatch::IntegrationTest
  def blob_params
    {
      blob: {
        filename: "photo.png",
        content_type: "image/png",
        byte_size: 282,
        checksum: Digest::MD5.base64digest("x" * 282)
      }
    }
  end

  test "a guest cannot start a direct upload" do
    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params, as: :json
    end

    assert_response :unauthorized
  end

  test "a signed in non-admin cannot start a direct upload" do
    sign_in_as(users(:one))

    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params, as: :json
    end

    assert_response :forbidden
  end

  test "an admin can start a direct upload" do
    admin = User.create!(username: "uploader", email_address: "uploader@test.com", password: "password123!", admin: true)
    sign_in_as(admin)

    assert_difference("ActiveStorage::Blob.count", 1) do
      post rails_direct_uploads_url, params: blob_params, as: :json
    end

    assert_response :success
    assert JSON.parse(response.body)["signed_id"].present?
    assert JSON.parse(response.body)["id"].present?
  end
end
