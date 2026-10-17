class Admin::MaintenanceController < Admin::BaseController
  def purge_unused_images
    deleted = PurgeUnattachedBlobsJob.perform_now

    message = deleted.zero? ? "There were no unused images to delete." : "Deleted #{helpers.pluralize(deleted, 'unused image')}."
    redirect_to admin_root_path, notice: message
  end
end
