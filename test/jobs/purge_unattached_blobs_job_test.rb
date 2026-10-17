require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  def create_blob(name, age:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/test.png"))),
      filename: name,
      content_type: "image/png"
    )
    blob.update_columns(created_at: age.ago)
    blob
  end

  test "deletes old files that were never attached" do
    orphan = create_blob("old.png", age: 3.days)

    perform_enqueued_jobs { PurgeUnattachedBlobsJob.perform_now }

    assert_not ActiveStorage::Blob.exists?(orphan.id)
  end

  test "keeps recent unattached files, so a post being written is safe" do
    recent = create_blob("recent.png", age: 1.hour)

    perform_enqueued_jobs { PurgeUnattachedBlobsJob.perform_now }

    assert ActiveStorage::Blob.exists?(recent.id)
  end

  test "keeps old files that are attached to a post" do
    blob = create_blob("used.png", age: 10.days)
    admin_posts(:one).images.attach(blob)

    perform_enqueued_jobs { PurgeUnattachedBlobsJob.perform_now }

    assert ActiveStorage::Blob.exists?(blob.id)
  end
end
