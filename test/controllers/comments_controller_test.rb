require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class CommentsIndexTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @author = users(:one)
  end

  def open_comments(params = {})
    get post_comments_path(@post, **params), headers: frame_headers("comments_panel")
  end

  def listed_ids
    css_select("#comments_list > li").map { |item| item["id"] }
  end

  # Who can read

  test "anyone can open the comments, even without signing in" do
    create_comment(@post, "Hello everyone")

    open_comments

    assert_response :success
    assert_select "turbo-frame#comments_panel"
    assert_select "#comments_list li", text: /Hello everyone/
  end

  test "a post that does not exist gives a 404" do
    get post_comments_path(0), headers: frame_headers("comments_panel")

    assert_response :not_found
  end

  # What is shown

  test "the header counts every comment of the post, replies included" do
    comment = create_comment(@post)
    create_comment(@post, "Reply", parent: comment)

    open_comments

    assert_select "#comments_count", "2"
  end

  test "a post without comments says so" do
    open_comments

    assert_select "#comments_empty", "No comments yet."
    assert_select "#comments_count", "0"
  end

  test "the empty message is not shown when there are comments" do
    create_comment(@post)

    open_comments

    assert_select "#comments_empty", 0
  end

  test "each comment shows the author, the text, a heart and the number of replies" do
    @author.update!(display_name: "Shown Name")
    comment = create_comment(@post, "Some words", user: @author)

    open_comments

    assert_select "##{dom_id(comment)}" do
      assert_select "a[href=?]", profile_path(@author.username), text: "Shown Name"
      assert_select "p", text: "Some words"
      assert_select "##{dom_id(comment, :like)} button"
      assert_select "##{dom_id(comment, :stats)}", /0 replies/
    end
  end

  test "text written by people is escaped" do
    @author.update!(display_name: "<b>Bold</b>")
    create_comment(@post, "<script>alert(1)</script>", user: @author)

    open_comments

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_not_includes response.body, "<b>Bold</b>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "replies are not listed as comments, only their number and a link to open them" do
    comment = create_comment(@post, "Top")
    create_comment(@post, "The reply text", parent: comment)

    open_comments

    assert_equal [ dom_id(comment) ], listed_ids
    assert_not_includes response.body, "The reply text"
    assert_select "##{dom_id(comment, :replies)} a[href=?]", comment_replies_path(comment), text: "View 1 reply"
  end

  test "a comment without replies has no link to open them" do
    comment = create_comment(@post)

    open_comments

    assert_select "##{dom_id(comment, :replies)} a", 0
  end

  # Sorting

  test "the newest comment comes first by default" do
    older = create_comment(@post, "Older")
    newer = create_comment(@post, "Newer")

    open_comments

    assert_equal [ dom_id(newer), dom_id(older) ], listed_ids
    assert_select "a.tab-active", text: "Latest"
  end

  test "an unknown sorting falls back to the newest first" do
    older = create_comment(@post, "Older")
    newer = create_comment(@post, "Newer")

    open_comments(sort: "nonsense; drop table")

    assert_equal [ dom_id(newer), dom_id(older) ], listed_ids
    assert_select "a.tab-active", text: "Latest"
  end

  test "the tabs link to the three orders and mark the current one" do
    open_comments(sort: "replies")

    assert_select "[role=tablist] a[role=tab]", 3
    assert_select "a.tab-active", text: "Most replies", count: 1
    assert_select "a[href=?]", post_comments_path(@post, sort: "latest"), text: "Latest"
    assert_select "a[href=?]", post_comments_path(@post, sort: "likes"), text: "Most liked"
  end

  test "most replies puts the comment with the most replies first" do
    quiet = create_comment(@post, "Quiet")
    busy = create_comment(@post, "Busy")
    newest = create_comment(@post, "Newest")
    2.times { create_comment(@post, "Reply", parent: busy) }

    open_comments(sort: "replies")

    assert_equal [ dom_id(busy), dom_id(newest), dom_id(quiet) ], listed_ids
  end

  test "most liked puts the comment with the most likes first" do
    plain = create_comment(@post, "Plain")
    popular = create_comment(@post, "Popular")
    liked_once = create_comment(@post, "Liked once")
    Like.create!(user: users(:one), likeable: popular)
    Like.create!(user: users(:two), likeable: popular)
    Like.create!(user: users(:one), likeable: liked_once)

    open_comments(sort: "likes")

    assert_equal [ dom_id(popular), dom_id(liked_once), dom_id(plain) ], listed_ids
  end

  # Load more

  test "ten comments are shown at first and Load more brings the rest" do
    comments = Array.new(12) { |index| create_comment(@post, "Comment #{index}") }

    open_comments
    assert_equal comments.reverse.first(10).map { |comment| dom_id(comment) }, listed_ids

    cursor = comments[2].id
    assert_select "turbo-frame#comments_more_#{cursor} a[href=?]", post_comments_path(@post, sort: "latest", cursor: cursor),
                  text: "Load more comments"

    get post_comments_path(@post, sort: "latest", cursor: cursor), headers: frame_headers("comments_more_#{cursor}")

    assert_response :success
    rest = css_select("turbo-frame#comments_more_#{cursor} li").map { |item| item["id"] }
    assert_equal [ dom_id(comments[1]), dom_id(comments[0]) ], rest
    assert_select "a", text: "Load more comments", count: 0
  end

  test "exactly ten comments need no Load more" do
    Array.new(10) { |index| create_comment(@post, "Comment #{index}") }

    open_comments

    assert_equal 10, listed_ids.size
    assert_select "a", text: "Load more comments", count: 0
  end

  test "Load more keeps the chosen sorting" do
    Array.new(11) { |index| create_comment(@post, "Comment #{index}") }

    open_comments(sort: "likes")

    assert_select "a[href*=?]", "sort=likes", text: "Load more comments"
  end

  test "a broken cursor starts from the beginning instead of failing" do
    create_comment(@post)

    open_comments(cursor: "garbage")

    assert_response :success
    assert_select "turbo-frame#comments_more_garbage li", 1
  end

  # The box for writing

  test "a signed in user sees the box with the character limit" do
    sign_in_as(@author)

    open_comments

    assert_select "#comment_form form[action=?]", post_comments_path(@post)
    assert_select "#comment_form form:not([data-turbo-frame])"
    assert_select "#comment_form textarea[maxlength='1000']"
    assert_select "#comment_form p", text: "Up to 1000 characters"
  end

  test "a guest sees the box too, which leaves the window for the log in page" do
    open_comments

    assert_select "#comment_form form[data-turbo-frame='_top']"
    assert_select "#comment_form p", text: "You will be asked to log in"
  end

  # Delete buttons

  test "the author and admins see Delete, other people and guests do not" do
    comment = create_comment(@post, "Mine", user: @author)
    delete_form = "##{dom_id(comment)} form[action=?]"

    open_comments
    assert_select delete_form, comment_path(comment), 0

    sign_in_as(create_user)
    open_comments
    assert_select delete_form, comment_path(comment), 0

    sign_in_as(@author)
    open_comments
    assert_select delete_form, comment_path(comment), 1

    sign_in_as(users(:two))
    open_comments
    assert_select delete_form, comment_path(comment), 1
  end

  test "a heart that the signed in user pressed shows as pressed" do
    comment = create_comment(@post)
    sign_in_as(@author)
    Like.create!(user: @author, likeable: comment)

    open_comments

    assert_select "##{dom_id(comment, :like)} button[aria-pressed=true][aria-label=?]", "Unlike (1)"
  end
end

class CommentsCreateTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    sign_in_as(@user)
  end

  def write_comment(body, headers: turbo_headers, **extra)
    post post_comments_path(@post), params: { comment: { body: body }.merge(extra) }, headers: headers
  end

  test "a comment is saved for the signed in user on the post" do
    assert_difference "Comment.count", 1 do
      write_comment("Nice post")
    end

    comment = Comment.last
    assert_equal @user, comment.user
    assert_equal @post, comment.post
    assert_nil comment.parent_id
    assert_equal "Nice post", comment.body
    assert_equal 1, @post.reload.comments_count
  end

  test "the answer adds the comment at the top, resets the box and updates both counts" do
    write_comment("Nice post")

    assert_turbo_stream_response
    assert_stream "remove", "comments_empty"
    assert_stream "prepend", "comments_list"
    assert_stream "replace", "comment_form"
    assert_stream "update", "comments_count"
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Nice post"
    assert_includes response.body, "<template>1</template>"
    assert_includes response.body, "Comments (1)"
  end

  test "text written by the user is escaped in the answer" do
    write_comment("<script>alert(1)</script>")

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "without Turbo the post page is loaded again" do
    write_comment("Nice post", headers: {})

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
    assert_equal 1, @post.reload.comments_count
  end

  test "an empty comment is refused and the box says why" do
    assert_no_difference "Comment.count" do
      write_comment("   ")
    end

    assert_response 422
    assert_stream "replace", "comment_form"
    assert_includes response.body, CGI.escapeHTML("Body can't be blank")
  end

  test "a comment over 1000 characters is refused but the typed text stays in the box" do
    assert_no_difference "Comment.count" do
      write_comment("a" * 1001)
    end

    assert_response 422
    assert_includes response.body, "Body is too long (maximum is 1000 characters)"
    assert_includes response.body, "a" * 1001
  end

  test "only the text is taken from the request" do
    other_post = create_post
    parent = create_comment(@post, "Top")

    write_comment("Sneaky", user_id: users(:two).id, post_id: other_post.id, parent_id: parent.id, likes_count: 99)

    comment = Comment.find_by!(body: "Sneaky")
    assert_equal @user, comment.user
    assert_equal @post, comment.post
    assert_nil comment.parent_id
    assert_equal 0, comment.likes_count
  end

  test "a request without the comment gives a 400" do
    post post_comments_path(@post), headers: turbo_headers

    assert_response :bad_request
  end

  test "a post that does not exist gives a 404" do
    post post_comments_path(0), params: { comment: { body: "Hello" } }, headers: turbo_headers

    assert_response :not_found
  end
end

class CommentsGuestTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
  end

  test "a guest cannot comment and is sent to log in" do
    assert_no_difference "Comment.count" do
      post post_comments_path(@post), params: { comment: { body: "Hello" } }, headers: turbo_headers
    end

    assert_response :see_other
    assert_redirected_to new_session_path
    assert_equal "Please log in to continue.", flash[:alert]
  end

  test "after logging in the guest returns to the post page" do
    post post_comments_path(@post), params: { comment: { body: "Hello" } },
         headers: { "Referer" => "http://www.example.com#{post_page_path_for(@post)}" }

    post session_path, params: { login: @user.username, password: "password" }

    assert_redirected_to post_page_path_for(@post)
    assert_equal 0, Comment.count
  end

  test "a guest cannot delete a comment" do
    comment = create_comment(@post)

    assert_no_difference "Comment.count" do
      delete comment_path(comment), headers: turbo_headers
    end

    assert_redirected_to new_session_path
  end
end

class CommentsDestroyTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @author = users(:one)
    @admin = users(:two)
    @comment = create_comment(@post, "To delete", user: @author)
  end

  test "the author deletes their own comment" do
    sign_in_as(@author)

    assert_difference "Comment.count", -1 do
      delete comment_path(@comment), headers: turbo_headers
    end

    assert_turbo_stream_response
    assert_stream "remove", dom_id(@comment)
    assert_stream "update", "comments_count"
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "<template>0</template>"
    assert_equal 0, @post.reload.comments_count
  end

  test "an admin can delete the comment of someone else" do
    sign_in_as(@admin)

    assert_difference "Comment.count", -1 do
      delete comment_path(@comment), headers: turbo_headers
    end

    assert_stream "remove", dom_id(@comment)
  end

  test "another user cannot delete it" do
    sign_in_as(create_user)

    assert_no_difference "Comment.count" do
      delete comment_path(@comment), headers: turbo_headers
    end

    assert_response :forbidden
    assert_equal 1, @post.reload.comments_count
  end

  test "deleting a comment also deletes its replies and lowers the count for all of them" do
    sign_in_as(@author)
    create_comment(@post, "Reply one", parent: @comment)
    create_comment(@post, "Reply two", parent: @comment)

    assert_difference "Comment.count", -3 do
      delete comment_path(@comment), headers: turbo_headers
    end

    assert_equal 0, @post.reload.comments_count
    assert_includes response.body, "<template>0</template>"
  end

  test "deleting a reply refreshes the numbers of the comment it belonged to" do
    sign_in_as(@author)
    reply = create_comment(@post, "A reply", parent: @comment)

    delete comment_path(reply), headers: turbo_headers

    assert_stream "remove", dom_id(reply)
    assert_stream "replace", dom_id(@comment, :stats)
    assert_equal 0, @comment.reload.replies_count
    assert_equal 1, @post.reload.comments_count
    assert_includes response.body, "0 replies"
  end

  test "without Turbo the post page is loaded again" do
    sign_in_as(@author)

    delete comment_path(@comment)

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
  end

  test "a comment that does not exist gives a 404" do
    sign_in_as(@author)

    delete comment_path(0), headers: turbo_headers

    assert_response :not_found
  end
end
