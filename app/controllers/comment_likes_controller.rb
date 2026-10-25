# Likes and unlikes a comment or a reply, for the signed in user
class CommentLikesController < ApplicationController
  rate_limit to: 60, within: 1.minute, by: -> { Current.session.user_id }, with: -> { head :too_many_requests }
  before_action :require_verified_email
  before_action :set_comment

  def create
    @comment.likes.find_or_create_by(user_id: Current.session.user_id)
    render_like
  rescue ActiveRecord::RecordNotUnique
    # Two clicks arrived at the same moment, the comment is already liked
    render_like
  end

  def destroy
    # destroy_all (not delete_all) so the like counter on the comment is updated
    @comment.likes.where(user_id: Current.session.user_id).destroy_all
    render_like
  end

  private
    def set_comment
      @comment = Comment.find(params[:comment_id])
    end

    # Turbo swaps the button in place; without Turbo the post page is simply loaded again
    def render_like
      @comment.reload

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@comment, :like),
            partial: "comments/like",
            locals: { comment: @comment }
          )
        end
        format.html do
          post = @comment.post
          redirect_to topic_card_post_path(post.card.topic.slug, post.card.slug, post.slug), status: :see_other
        end
      end
    end
end
