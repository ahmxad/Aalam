class PagesController < ApplicationController
  def home
  end

  def contact
  end

  def explore
    @posts = Admin::Post.all
  end

  def about
  end
def show
    @post = Admin::Post.find(params[:id])
end
end
