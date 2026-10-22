require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class CommentLikesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    @comment = create_comment(@post, "Likeable", user: users(:two))
    sign_in_as(@user)
  end

  test "liking a comment creates one like for the signed in user" do
    assert_difference "Like.count", 1 do
      post comment_like_path(@comment), headers: turbo_headers
    end

    like = Like.last
    assert_equal @user, like.user
    assert_equal @comment, like.likeable
    assert_equal 1, @comment.reload.likes_count
  end

  test "the answer replaces the heart with the new state and count" do
    post comment_like_path(@comment), headers: turbo_headers

    assert_turbo_stream_response
    assert_stream "replace", dom_id(@comment, :like)
    assert_includes response.body, "Unlike (1)"
    assert_includes response.body, 'aria-pressed="true"'
  end

  test "the like of a comment does not change the likes of the post" do
    post comment_like_path(@comment), headers: turbo_headers

    assert_equal 0, @post.reload.likes_count
  end

  test "a reply can be liked and only its own count changes" do
    reply = create_comment(@post, "A reply", parent: @comment)

    post comment_like_path(reply), headers: turbo_headers

    assert_equal 1, reply.reload.likes_count
    assert_equal 0, @comment.reload.likes_count
    assert_stream "replace", dom_id(reply, :like)
  end

  test "the count includes the likes of other people" do
    Like.create!(user: users(:two), likeable: @comment)

    post comment_like_path(@comment), headers: turbo_headers

    assert_includes response.body, "Unlike (2)"
  end

  test "liking twice keeps a single like" do
    2.times { post comment_like_path(@comment), headers: turbo_headers }

    assert_equal 1, @comment.likes.count
    assert_equal 1, @comment.reload.likes_count
  end

  test "unliking removes the like and shows the heart as not pressed" do
    Like.create!(user: @user, likeable: @comment)

    assert_difference "Like.count", -1 do
      delete comment_like_path(@comment), headers: turbo_headers
    end

    assert_equal 0, @comment.reload.likes_count
    assert_includes response.body, "Like (0)"
    assert_includes response.body, 'aria-pressed="false"'
  end

  test "unliking a comment that is not liked does nothing" do
    assert_no_difference "Like.count" do
      delete comment_like_path(@comment), headers: turbo_headers
    end

    assert_response :success
  end

  test "unliking only removes the like of the signed in user" do
    Like.create!(user: users(:two), likeable: @comment)
    Like.create!(user: @user, likeable: @comment)

    delete comment_like_path(@comment), headers: turbo_headers

    assert_equal [ users(:two) ], @comment.likes.map(&:user)
  end

  test "without Turbo the post page is loaded again" do
    post comment_like_path(@comment)

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
    assert_equal 1, @comment.reload.likes_count
  end

  test "a guest is sent to log in and nothing changes" do
    delete session_path

    assert_no_difference "Like.count" do
      post comment_like_path(@comment), headers: turbo_headers
    end

    assert_response :see_other
    assert_redirected_to new_session_path
    assert_equal "Please log in to continue.", flash[:alert]
  end

  test "a comment that does not exist gives a 404" do
    post comment_like_path(0), headers: turbo_headers

    assert_response :not_found
  end
end
