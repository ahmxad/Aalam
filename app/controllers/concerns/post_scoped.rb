# Shared by the controllers behind the buttons on a post page
module PostScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_post
    rate_limit to: 60, within: 1.minute, by: -> { rate_limit_key }, with: -> { head :too_many_requests }
  end

  private
    def set_post
      @post = Admin::Post.find(params[:post_id])
    end

    # Signed in people are counted one by one, visitors by their address.
    # Asking whether someone is signed in also reads their session, which pages open to visitors do not do otherwise.
    def rate_limit_key
      authenticated? ? Current.session.user_id : request.remote_ip
    end

    def post_page_path
      topic_card_post_path(@post.card.topic.slug, @post.card.slug, @post.slug)
    end

    # Turbo swaps the buttons in place; without Turbo the post page is simply loaded again
    def render_post_actions
      @post.reload

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@post, :actions),
            partial: "shared/post_actions",
            locals: { post: @post }
          )
        end
        format.html { redirect_to post_page_path, status: :see_other }
      end
    end
end
