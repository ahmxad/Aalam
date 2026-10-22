require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @user = users(:one)
    sign_in_as(@user)
  end

  # Saving from the post page

  test "saving a post creates one save for the signed in user" do
    assert_difference "Bookmark.count", 1 do
      post post_bookmark_path(@post), headers: turbo_headers
    end

    bookmark = Bookmark.last
    assert_equal @user, bookmark.user
    assert_equal @post, bookmark.post
    assert_equal 1, @post.reload.bookmarks_count
  end

  test "the answer replaces the buttons with the new state and count" do
    post post_bookmark_path(@post), headers: turbo_headers

    assert_turbo_stream_response
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Saved (1)"
  end

  test "without Turbo the post page is loaded again" do
    post post_bookmark_path(@post)

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
  end

  test "saving twice keeps a single save" do
    2.times { post post_bookmark_path(@post), headers: turbo_headers }

    assert_equal 1, @post.bookmarks.count
    assert_equal 1, @post.reload.bookmarks_count
  end

  test "removing a save lowers the count and shows the Save button again" do
    Bookmark.create!(user: @user, post: @post)

    assert_difference "Bookmark.count", -1 do
      delete post_bookmark_path(@post), headers: turbo_headers
    end

    assert_equal 0, @post.reload.bookmarks_count
    assert_stream "replace", dom_id(@post, :actions)
    assert_includes response.body, "Save (0)"
  end

  test "removing a save that does not exist does nothing" do
    assert_no_difference "Bookmark.count" do
      delete post_bookmark_path(@post), headers: turbo_headers
    end

    assert_response :success
  end

  test "removing a save only removes the save of the signed in user" do
    Bookmark.create!(user: users(:two), post: @post)
    Bookmark.create!(user: @user, post: @post)

    delete post_bookmark_path(@post), headers: turbo_headers

    assert_equal [ users(:two) ], @post.bookmarks.map(&:user)
  end

  test "the buttons show a saved post as saved after a reload" do
    Bookmark.create!(user: @user, post: @post)

    get post_page_path_for(@post)

    assert_select "##{dom_id(@post, :actions)} button[aria-pressed=true][aria-label=?]", "Saved (1)"
  end

  test "a post that does not exist gives a 404" do
    post post_bookmark_path(0), headers: turbo_headers

    assert_response :not_found
  end

  # Removing from the saved posts list on the profile page

  test "removing from the saved list removes the row and leaves the other rows alone" do
    other_post = create_post(card: @post.card)
    Bookmark.create!(user: @user, post: @post)
    Bookmark.create!(user: @user, post: other_post)

    delete post_bookmark_path(@post, from: "saved"), headers: turbo_headers

    assert_turbo_stream_response
    assert_stream "remove", dom_id(@post, :saved)
    assert_no_stream_for "saved_posts_empty"
    assert_equal [ other_post ], @user.bookmarks.map(&:post)
  end

  test "removing the last saved post shows the empty message" do
    Bookmark.create!(user: @user, post: @post)

    delete post_bookmark_path(@post, from: "saved"), headers: turbo_headers

    assert_stream "remove", dom_id(@post, :saved)
    assert_stream "replace", "saved_posts_empty"
    assert_equal 0, @post.reload.bookmarks_count
  end

  test "removing from the saved list without Turbo returns to the profile" do
    Bookmark.create!(user: @user, post: @post)

    delete post_bookmark_path(@post, from: "saved")

    assert_response :see_other
    assert_redirected_to profile_path(@user.username)
  end
end
