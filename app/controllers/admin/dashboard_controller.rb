class Admin::DashboardController < Admin::BaseController
  def index
    @topics_count = Admin::Topic.count
    @cards_count = Admin::Card.count
    @posts_count = Admin::Post.count
    @unused_images_count = PurgeUnattachedBlobsJob.unused_blobs.count
  end
end
