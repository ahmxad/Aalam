class RepliesController < ApplicationController
  PER_PAGE = 5

  allow_unauthenticated_access only: :index
  before_action :set_comment

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { Current.session.user_id }, name: "create",
             with: -> { render_invalid_form("You are replying too fast. Please wait a minute and try again.", :too_many_requests) }

  def index
    load_replies(params[:cursor])

    # A "View more replies" request only needs the next batch
    render :page if params[:cursor].present?
  end

  def create
    @reply = @parent.replies.new(reply_params)
    @reply.user = Current.session.user
    @reply.post = @post

    if @reply.save
      @post.reload
      @parent.reload
      load_replies

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to post_page_path, status: :see_other }
      end
    else
      render :invalid, status: :unprocessable_content, formats: :turbo_stream
    end
  end

  private
    # The comment that was replied to. A reply to a reply is attached to the comment above it.
    def set_comment
      @target = Comment.find(params[:comment_id])
      @parent = @target.parent || @target
      @post = @parent.post
    end

    # The newest replies first. The cursor is the last reply of the previous batch.
    def load_replies(cursor = nil)
      page = @parent.replies
                    .includes(user: { avatar_attachment: :blob })
                    .sorted_page(sort: "latest", cursor: cursor, limit: PER_PAGE + 1)
                    .to_a

      @replies = page.first(PER_PAGE)
      @next_cursor = page[PER_PAGE - 1].cursor_for("latest") if page.size > PER_PAGE
    end

    def reply_params
      params.expect(comment: [ :body ])
    end

    def post_page_path
      topic_card_post_path(@post.card.topic.slug, @post.card.slug, @post.slug)
    end

    # Shows a message in the reply box and keeps what the user already typed
    def render_invalid_form(message, status)
      @reply = Comment.new(body: params.dig(:comment, :body).to_s.first(Comment::MAX_LENGTH))
      @reply.errors.add(:base, message)
      render :invalid, status: status, formats: :turbo_stream
    end
end
