class BookmarksController < ApplicationController
  include PostScoped

  def create
    @post.bookmarks.find_or_create_by(user_id: Current.session.user_id)
    render_post_actions
  rescue ActiveRecord::RecordNotUnique
    render_post_actions
  end

  def destroy
    @post.bookmarks.where(user_id: Current.session.user_id).destroy_all
    render_post_actions
  end
end
