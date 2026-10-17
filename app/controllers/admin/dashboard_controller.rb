class Admin::DashboardController < Admin::BaseController
  def index
    @topics_count = Admin::Topic.count
    @cards_count = Admin::Card.count
    @posts_count = Admin::Post.count
    @unused_images_count = PurgeUnattachedBlobsJob.unused_blobs.count
    @recent_posts = Admin::Post.includes(card: :topic).order(updated_at: :desc).limit(5)
  end
end
