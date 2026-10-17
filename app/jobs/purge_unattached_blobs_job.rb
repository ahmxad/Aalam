# Deletes uploaded files that never got attached to anything, for example an image that was
# chosen in the post form but whose post was never saved.
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  # Younger files are left alone, so a post that is still being written is safe
  GRACE_PERIOD = 2.days

  # The files this job would delete right now
  def self.unused_blobs
    ActiveStorage::Blob.unattached.where(created_at: ..GRACE_PERIOD.ago)
  end

  # Returns how many files were deleted
  def perform
    deleted = 0

    self.class.unused_blobs.find_each do |blob|
      blob.purge
      deleted += 1
    end

    deleted
  end
end
