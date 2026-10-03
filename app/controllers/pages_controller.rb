class PagesController < ApplicationController
  allow_unauthenticated_access
  def home
  end

  def contact
  end

  def explore
    @topics = Admin::Topic.with_attached_image.all
  end

  def about
  end
def show
    @post = Admin::Post.find(params[:id])
end
def card
  @card = Admin::Card.find(params[:id])
  @posts = @card.posts
end
  def topic
    @topic = Admin::Topic.find(params[:id])
    @cards = @topic.cards.with_attached_image
  end
end
