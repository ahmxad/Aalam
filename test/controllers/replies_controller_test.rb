require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class RepliesIndexTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    @comment = create_comment(@post, "Top comment")
  end

  def open_replies(target = @comment, params = {})
    top = target.parent || target
    get comment_replies_path(target, **params), headers: frame_headers(dom_id(top, :replies))
  end

  def reply_ids(frame_selector)
    css_select("#{frame_selector} li[id^='comment_']").map { |item| item["id"] }
  end

  test "anyone can open the replies, even without signing in" do
    create_comment(@post, "First reply", parent: @comment)

    open_replies

    assert_response :success
    assert_select "turbo-frame##{dom_id(@comment, :replies)} li", text: /First reply/
  end

  test "the newest reply comes first" do
    older = create_comment(@post, "Older", parent: @comment)
    newer = create_comment(@post, "Newer", parent: @comment)

    open_replies

    assert_equal [ dom_id(newer), dom_id(older) ], reply_ids("turbo-frame")
  end

  test "five replies are shown at first and View more brings the rest" do
    replies = Array.new(7) { |index| create_comment(@post, "Reply #{index}", parent: @comment) }

    open_replies
    assert_equal replies.reverse.first(5).map { |reply| dom_id(reply) }, reply_ids("turbo-frame")

    cursor = replies[2].id
    assert_select "a[href=?]", comment_replies_path(@comment, cursor: cursor), text: "View more replies"

    get comment_replies_path(@comment, cursor: cursor), headers: frame_headers("replies_more_#{@comment.id}_#{cursor}")

    assert_response :success
    assert_select "turbo-frame#replies_more_#{@comment.id}_#{cursor}"
    assert_equal [ dom_id(replies[1]), dom_id(replies[0]) ], reply_ids("turbo-frame")
    assert_select "a", text: "View more replies", count: 0
  end

  test "five replies or fewer need no View more" do
    Array.new(5) { |index| create_comment(@post, "Reply #{index}", parent: @comment) }

    open_replies

    assert_select "a", text: "View more replies", count: 0
  end

  test "asking for the replies of a reply gives the replies of the comment above it" do
    reply = create_comment(@post, "A reply", parent: @comment)
    create_comment(@post, "Another reply", parent: @comment)

    open_replies(reply)

    assert_select "turbo-frame##{dom_id(@comment, :replies)}"
    assert_equal 2, reply_ids("turbo-frame").size
  end

  test "each reply has a heart, and its reply box starts with the name of the person replied to" do
    reply = create_comment(@post, "A reply", user: users(:two), parent: @comment)

    open_replies

    assert_select "##{dom_id(reply)}" do
      assert_select "##{dom_id(reply, :like)} button"
      assert_select "details##{dom_id(reply, :reply_form)} textarea", text: /@#{users(:two).username}/
    end
  end

  test "text written by people is escaped" do
    create_comment(@post, "<script>alert(1)</script>", parent: @comment)

    open_replies

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "only the author and admins see Delete on a reply" do
    reply = create_comment(@post, "A reply", user: @user, parent: @comment)
    delete_form = "##{dom_id(reply)} form[action=?]"

    open_replies
    assert_select delete_form, comment_path(reply), 0

    sign_in_as(create_user)
    open_replies
    assert_select delete_form, comment_path(reply), 0

    sign_in_as(@user)
    open_replies
    assert_select delete_form, comment_path(reply), 1

    sign_in_as(users(:two))
    open_replies
    assert_select delete_form, comment_path(reply), 1
  end

  test "a comment that does not exist gives a 404" do
    get comment_replies_path(0), headers: frame_headers("anything")

    assert_response :not_found
  end
end

class RepliesCreateTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    @comment = create_comment(@post, "Top comment", user: users(:two))
    sign_in_as(@user)
  end

  def reply_to(target, body, headers: turbo_headers, **extra)
    post comment_replies_path(target), params: { comment: { body: body }.merge(extra) }, headers: headers
  end

  test "a reply is saved under the comment for the signed in user" do
    assert_difference "Comment.count", 1 do
      reply_to(@comment, "Good point")
    end

    reply = Comment.last
    assert_equal @user, reply.user
    assert_equal @comment, reply.parent
    assert_equal @post, reply.post
    assert_equal 1, @comment.reload.replies_count
    assert_equal 2, @post.reload.comments_count
  end

  test "the answer draws the comment again with its replies open, and updates the counts" do
    reply_to(@comment, "Good point")

    assert_turbo_stream_response
    assert_stream "replace", dom_id(@comment)
    assert_stream "update", "comments_count"
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Good point"
    assert_includes response.body, "1 reply"
    assert_includes response.body, "<template>2</template>"
    assert_not_includes response.body, "View 1 reply"
  end

  test "the new reply comes before the older ones" do
    create_comment(@post, "Older reply", parent: @comment)

    reply_to(@comment, "Newest reply")

    assert_operator response.body.index("Newest reply"), :<, response.body.index("Older reply")
  end

  test "a reply to a reply is attached to the comment above it" do
    reply = create_comment(@post, "First reply", user: users(:two), parent: @comment)

    reply_to(reply, "@#{users(:two).username} thanks")

    new_reply = Comment.find_by!(body: "@#{users(:two).username} thanks")
    assert_equal @comment, new_reply.parent
    assert_equal 2, @comment.reload.replies_count
    assert_equal 0, reply.reload.replies_count
    assert_stream "replace", dom_id(@comment)
  end

  test "text written by the user is escaped in the answer" do
    reply_to(@comment, "<script>alert(1)</script>")

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "without Turbo the post page is loaded again" do
    reply_to(@comment, "Good point", headers: {})

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
    assert_equal 1, @comment.reload.replies_count
  end

  test "an empty reply is refused and its box opens again with the reason" do
    assert_no_difference "Comment.count" do
      reply_to(@comment, "   ")
    end

    assert_response 422
    assert_stream "replace", dom_id(@comment, :reply_form)
    assert_includes response.body, CGI.escapeHTML("Body can't be blank")
    assert_match(/<details[^>]*\sopen/, response.body)
  end

  test "an empty reply to a reply is shown in the box of that reply" do
    reply = create_comment(@post, "First reply", parent: @comment)

    reply_to(reply, "   ")

    assert_response 422
    assert_stream "replace", dom_id(reply, :reply_form)
  end

  test "a reply over 1000 characters is refused" do
    assert_no_difference "Comment.count" do
      reply_to(@comment, "a" * 1001)
    end

    assert_response 422
    assert_includes response.body, "Body is too long (maximum is 1000 characters)"
  end

  test "only the text is taken from the request" do
    other_post = create_post
    other_comment = create_comment(other_post, "Elsewhere")

    reply_to(@comment, "Sneaky", user_id: users(:two).id, post_id: other_post.id, parent_id: other_comment.id)

    reply = Comment.find_by!(body: "Sneaky")
    assert_equal @user, reply.user
    assert_equal @post, reply.post
    assert_equal @comment, reply.parent
  end

  test "a request without the reply gives a 400" do
    post comment_replies_path(@comment), headers: turbo_headers

    assert_response :bad_request
  end

  test "a comment that does not exist gives a 404" do
    post comment_replies_path(0), params: { comment: { body: "Hello" } }, headers: turbo_headers

    assert_response :not_found
  end

  test "a guest cannot reply and is sent to log in" do
    delete session_path

    assert_no_difference "Comment.count" do
      reply_to(@comment, "Hello")
    end

    assert_response :see_other
    assert_redirected_to new_session_path
  end
end
