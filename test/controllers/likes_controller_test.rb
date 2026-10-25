require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class LikesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    sign_in_as(@user)
  end

  test "liking a post creates one like for the signed in user" do
    assert_difference "Like.count", 1 do
      post post_like_path(@post), headers: turbo_headers
    end

    like = Like.last
    assert_equal @user, like.user
    assert_equal @post, like.likeable
    assert_equal 1, @post.reload.likes_count
  end

  test "the answer replaces the buttons with the new state and count" do
    post post_like_path(@post), headers: turbo_headers

    assert_turbo_stream_response
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Liked (1)"
  end

  test "the count includes the likes of other people" do
    Like.create!(user: users(:two), likeable: @post)

    post post_like_path(@post), headers: turbo_headers

    assert_includes response.body, "Liked (2)"
  end

  test "without Turbo the post page is loaded again" do
    post post_like_path(@post)

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
    assert_equal 1, @post.reload.likes_count
  end

  test "liking twice keeps a single like" do
    2.times { post post_like_path(@post), headers: turbo_headers }

    assert_equal 1, @post.likes.count
    assert_equal 1, @post.reload.likes_count
  end

  test "unliking removes the like and lowers the count" do
    Like.create!(user: @user, likeable: @post)

    assert_difference "Like.count", -1 do
      delete post_like_path(@post), headers: turbo_headers
    end

    assert_equal 0, @post.reload.likes_count
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Like (0)"
  end

  test "unliking a post that is not liked does nothing" do
    assert_no_difference "Like.count" do
      delete post_like_path(@post), headers: turbo_headers
    end

    assert_response :success
  end

  test "unliking only removes the like of the signed in user" do
    Like.create!(user: users(:two), likeable: @post)
    Like.create!(user: @user, likeable: @post)

    delete post_like_path(@post), headers: turbo_headers

    assert_equal [ users(:two) ], @post.likes.map(&:user)
    assert_equal 1, @post.reload.likes_count
  end

  test "the buttons show a liked post as liked after a reload" do
    Like.create!(user: @user, likeable: @post)

    get post_page_path_for(@post)

    assert_select "##{dom_id(@post, :actions)} button[aria-pressed=true][aria-label=?]", "Liked (1)"
  end

  test "a post that does not exist gives a 404" do
    post post_like_path(0), headers: turbo_headers

    assert_response :not_found
  end
end
