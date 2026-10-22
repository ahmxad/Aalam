class CommentsController < ApplicationController
  include PostScoped

  allow_unauthenticated_access only: :index
  before_action :require_verified_email, only: :create
  skip_before_action :set_post, only: :destroy
  before_action :set_comment, only: :destroy

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { Current.session.user_id }, name: "create",
             with: -> { render_invalid_form("You are commenting too fast. Please wait a minute and try again.", :too_many_requests) }

  def index
    @sort = Comment::SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "latest"

    # One extra comment is loaded, only to find out whether another page exists
    page = @post.comments.top_level
                .includes(user: { avatar_attachment: :blob })
                .sorted_page(sort: @sort, cursor: params[:cursor], limit: Comment::PAGE_SIZE + 1)
                .to_a

    @comments = page.first(Comment::PAGE_SIZE)
    @next_cursor = page[Comment::PAGE_SIZE - 1].cursor_for(@sort) if page.size > Comment::PAGE_SIZE

    # A "Load more" request only needs the next batch, not the whole window
    render :page if params[:cursor].present?
  end

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = Current.session.user

    if @comment.save
      @post.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to post_page_path, status: :see_other }
      end
    else
      render :invalid, status: :unprocessable_content, formats: :turbo_stream
    end
  end

  def destroy
    return head :forbidden unless @comment.deletable_by?(Current.session.user)

    parent = @comment.parent
    @comment.destroy
    @post.reload
    @parent = parent&.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to post_page_path, status: :see_other }
    end
  end

  private
    def set_comment
      @comment = Comment.find(params[:id])
      @post = @comment.post
    end

    def comment_params
      params.expect(comment: [ :body ])
    end

    # Shows a message in the comment box and keeps what the user already typed
    def render_invalid_form(message, status)
      @comment = Comment.new(body: params.dig(:comment, :body).to_s.first(Comment::MAX_LENGTH))
      @comment.errors.add(:base, message)
      render :invalid, status: status, formats: :turbo_stream
    end
end
