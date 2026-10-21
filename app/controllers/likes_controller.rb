class LikesController < ApplicationController
  include PostScoped

  def create
    @post.likes.find_or_create_by(user_id: Current.session.user_id)
    render_post_actions
  rescue ActiveRecord::RecordNotUnique
    # Two clicks arrived at the same moment, the post is already liked
    render_post_actions
  end

  def destroy
    # destroy_all (not delete_all) so the like counter on the post is updated
    @post.likes.where(user_id: Current.session.user_id).destroy_all
    render_post_actions
  end
end
