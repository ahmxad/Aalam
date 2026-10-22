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
    params[:from] == "saved" ? render_removed_from_saved_list : render_post_actions
  end

  private
    # Pressed in the saved posts list on the profile page, so the row goes instead of the buttons changing
    def render_removed_from_saved_list
      respond_to do |format|
        format.turbo_stream do
          streams = [ turbo_stream.remove(helpers.dom_id(@post, :saved)) ]
          unless Current.session.user.bookmarks.exists?
            streams << turbo_stream.replace("saved_posts_empty", partial: "saved_posts/empty", locals: { visible: true })
          end
          render turbo_stream: streams
        end
        format.html { redirect_to profile_path(Current.session.user.username), status: :see_other }
      end
    end
end
