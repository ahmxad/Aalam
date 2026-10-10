class Admin::DashboardController < ApplicationController
  def index
    @topics_count = Admin::Topic.count
    @cards_count = Admin::Card.count
    @posts_count = Admin::Post.count
  end
end
