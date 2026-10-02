class PagesController < ApplicationController
  def home
  end

  def contact
  end

  def explore
    @cards = Admin::Card.all
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
end
