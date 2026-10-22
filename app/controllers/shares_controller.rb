# Counts a successful share of a post. Visitors who are not signed in can share too.
class SharesController < ApplicationController
  include PostScoped

  allow_unauthenticated_access only: :create

  # Stricter than the limit shared by the other buttons, because every request raises a public number
  rate_limit to: 10, within: 1.minute, only: :create, name: "create",
             by: -> { Current.session&.user_id || request.remote_ip },
             with: -> { head :too_many_requests }

  def create
    # One atomic database update, so two shares at the same moment are both counted
    Admin::Post.increment_counter(:shares_count, @post.id)
    @post.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          helpers.dom_id(@post, :shares_count),
          helpers.number_with_delimiter(@post.shares_count)
        )
      end
      format.html { redirect_to post_page_path, status: :see_other }
    end
  end
end
