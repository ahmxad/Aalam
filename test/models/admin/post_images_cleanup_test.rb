require "test_helper"

class Admin::PostImagesCleanupTest < ActiveJob::TestCase
  test "deleting a post also deletes its image files" do
    post_record = admin_posts(:one)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/test.png"))),
      filename: "attached.png",
      content_type: "image/png"
    )
    post_record.images.attach(blob)

    perform_enqueued_jobs { post_record.destroy! }

    assert_not ActiveStorage::Blob.exists?(blob.id)
  end
end
