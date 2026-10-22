require "test_helper"
require_relative "../support/post_builder"

# What happens when someone who is not signed in presses a button that needs an account
class GuestEngagementTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @post = create_post
    @user = users(:one)
  end

  def referer_for(path)
    { "Referer" => "http://www.example.com#{path}" }
  end

  def log_in
    post session_path, params: { login: @user.username, password: "password" }
  end

  test "a guest pressing Like or Save is sent to the log in page and nothing changes" do
    assert_no_difference [ "Like.count", "Bookmark.count" ] do
      post post_like_path(@post)
      assert_response :see_other
      assert_redirected_to new_session_path
      assert_equal "Please log in to continue.", flash[:alert]

      post post_bookmark_path(@post)
      assert_response :see_other
      assert_redirected_to new_session_path
    end
  end

  test "a guest pressing a button that undoes something is sent to the log in page too" do
    delete post_like_path(@post)
    assert_response :see_other
    assert_redirected_to new_session_path

    delete post_bookmark_path(@post)
    assert_response :see_other
    assert_redirected_to new_session_path
  end

  test "after logging in the guest returns to the post page, and the press was not applied" do
    post post_like_path(@post), headers: referer_for(post_page_path_for(@post))

    log_in

    assert_redirected_to post_page_path_for(@post)
    assert_equal 0, @post.reload.likes_count
  end

  test "the place to return to also works for Save and for undoing" do
    delete post_bookmark_path(@post), headers: referer_for(post_page_path_for(@post))

    log_in

    assert_redirected_to post_page_path_for(@post)
  end

  test "the query of the page to return to is kept" do
    post post_like_path(@post), headers: referer_for("#{post_page_path_for(@post)}?from=search")

    log_in

    assert_redirected_to "#{post_page_path_for(@post)}?from=search"
  end

  test "a page on another site is never used as the place to return to" do
    post post_like_path(@post), headers: { "Referer" => "http://evil.example.com/phish" }

    log_in

    assert_redirected_to root_url
  end

  test "a broken or missing referer sends the user to the home page after logging in" do
    [ { "Referer" => "http://%zz" }, { "Referer" => "//evil.example.com/path" }, {} ].each do |headers|
      post post_like_path(@post), headers: headers

      log_in

      assert_redirected_to root_url
      delete session_path
    end
  end

  test "opening a page that needs an account returns to that page after logging in" do
    get saved_posts_path

    assert_redirected_to new_session_path
    assert_nil flash[:alert], "the message is only for button presses"

    log_in

    assert_redirected_to saved_posts_url
  end

  test "a guest can still share" do
    assert_difference -> { @post.reload.shares_count }, 1 do
      post post_share_path(@post)
    end

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
  end
end
