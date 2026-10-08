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
  @topic = Admin::Topic.find_by!(slug: params[:topic_slug])
  @card = @topic.cards.find_by!(slug: params[:card_slug])
  @post = @card.posts.find_by!(slug: params[:post_slug])
end
def card
  @topic = Admin::Topic.find_by!(slug: params[:topic_slug])
  @card = @topic.cards.find_by!(slug: params[:card_slug])
  @posts = @card.posts
end
  def topic
    @topic = Admin::Topic.find_by!(slug: params[:topic_slug])
    @cards = @topic.cards.with_attached_image
  end
end
