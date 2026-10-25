require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"
require_relative "../support/rate_limit_helpers"

class EngagementRateLimitTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers
  include RateLimitHelpers

  setup do
    @post = create_post
    @user = users(:one)
    sign_in_as(@user)
  end

  # Like, Save and the heart on a comment: sixty a minute for each user

  test "the sixty-first press on Like in a minute is refused" do
    with_rate_limits do
      60.times { post post_like_path(@post), headers: turbo_headers }
      assert_response :success

      post post_like_path(@post), headers: turbo_headers
    end

    assert_response :too_many_requests
    assert_equal 1, @post.reload.likes_count
  end

  test "the sixty-first press on Save in a minute is refused" do
    with_rate_limits do
      60.times { post post_bookmark_path(@post), headers: turbo_headers }
      assert_response :success

      post post_bookmark_path(@post), headers: turbo_headers
    end

    assert_response :too_many_requests
    assert_equal 1, @post.reload.bookmarks_count
  end

  test "the sixty-first press on the heart of a comment in a minute is refused" do
    comment = create_comment(@post, "Likeable", user: users(:two))

    with_rate_limits do
      60.times { post comment_like_path(comment), headers: turbo_headers }
      assert_response :success

      post comment_like_path(comment), headers: turbo_headers
    end

    assert_response :too_many_requests
    assert_equal 1, comment.reload.likes_count
  end

  test "the limit is counted per user, not per address" do
    other = create_user("other_liker")
    other.verify_email!

    with_rate_limits do
      61.times { post post_like_path(@post), headers: turbo_headers }
      assert_response :too_many_requests

      sign_in_as(other)
      post post_like_path(@post), headers: turbo_headers
    end

    assert_response :success
    assert_equal 2, @post.reload.likes_count
  end

  # Comments and replies: ten a minute

  test "the eleventh comment in a minute is refused, and the text stays in the box" do
    with_rate_limits do
      10.times do |index|
        post post_comments_path(@post), params: { comment: { body: "Comment #{index}" } }, headers: turbo_headers
        assert_response :success
      end

      assert_no_difference "Comment.count" do
        post post_comments_path(@post), params: { comment: { body: "One too many" } }, headers: turbo_headers
      end
    end

    assert_response :too_many_requests
    assert_stream "replace", "comment_form"
    assert_includes response.body, "You are commenting too fast. Please wait a minute and try again."
    assert_includes response.body, "One too many"
    assert_equal 10, @post.reload.comments_count
  end

  test "the eleventh reply in a minute is refused, and the text stays in the box" do
    comment = create_comment(@post, "Top", user: users(:two))

    with_rate_limits do
      10.times do |index|
        post comment_replies_path(comment), params: { comment: { body: "Reply #{index}" } }, headers: turbo_headers
        assert_response :success
      end

      assert_no_difference "Comment.count" do
        post comment_replies_path(comment), params: { comment: { body: "One too many" } }, headers: turbo_headers
      end
    end

    assert_response :too_many_requests
    assert_stream "replace", dom_id(comment, :reply_form)
    assert_includes response.body, "You are replying too fast. Please wait a minute and try again."
    assert_includes response.body, "One too many"
    assert_equal 11, @post.reload.comments_count
  end

  test "comments and replies are counted separately" do
    comment = create_comment(@post, "Top", user: users(:two))

    with_rate_limits do
      11.times do |index|
        post post_comments_path(@post), params: { comment: { body: "Comment #{index}" } }, headers: turbo_headers
      end
      assert_response :too_many_requests

      post comment_replies_path(comment), params: { comment: { body: "A reply" } }, headers: turbo_headers
    end

    assert_response :success
  end

  # Share: ten a minute, for visitors as well

  test "the eleventh share in a minute is refused and not counted" do
    with_rate_limits do
      10.times { post post_share_path(@post), headers: turbo_headers }
      assert_response :success

      post post_share_path(@post), headers: turbo_headers
    end

    assert_response :too_many_requests
    assert_equal 10, @post.reload.shares_count
  end

  test "a visitor and a signed in user are counted separately" do
    delete session_path

    with_rate_limits do
      11.times { post post_share_path(@post), headers: turbo_headers }
      assert_response :too_many_requests

      sign_in_as(@user)
      post post_share_path(@post), headers: turbo_headers
    end

    assert_response :success
    assert_equal 11, @post.reload.shares_count
  end
end

class SearchAndUsernameRateLimitTest < ActionDispatch::IntegrationTest
  include RateLimitHelpers

  test "the sixty-first username check in a minute is refused" do
    with_rate_limits do
      60.times { get username_availability_path, params: { username: "some_name" } }
      assert_response :success

      get username_availability_path, params: { username: "some_name" }
    end

    assert_response :too_many_requests
  end

  test "the thirty-first search in a minute is refused with a plain message" do
    with_rate_limits do
      30.times { get search_path, params: { q: "anything" } }
      assert_response :success

      get search_path, params: { q: "anything" }
    end

    assert_response :too_many_requests
    assert_equal "Too many searches. Please wait a minute and try again.", response.body
  end

  test "ordinary pages are never limited" do
    with_rate_limits do
      70.times { get about_path }
    end

    assert_response :success
  end
end
