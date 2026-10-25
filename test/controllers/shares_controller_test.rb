require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class SharesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup { @post = create_post }

  test "a visitor who is not signed in can share and the share is counted" do
    assert_difference -> { @post.reload.shares_count }, 1 do
      post post_share_path(@post), headers: turbo_headers
    end

    assert_turbo_stream_response
    assert_stream "update", dom_id(@post, :shares_count)
    assert_includes response.body, "<template>1</template>"
  end

  test "a signed in user can share too" do
    sign_in_as(users(:one))

    assert_difference -> { @post.reload.shares_count }, 1 do
      post post_share_path(@post), headers: turbo_headers
    end

    assert_turbo_stream_response
  end

  test "every share is counted, even from the same person" do
    3.times { post post_share_path(@post), headers: turbo_headers }

    assert_equal 3, @post.reload.shares_count
    assert_includes response.body, "<template>3</template>"
  end

  test "a share only counts for its own post" do
    other_post = create_post(card: @post.card)

    post post_share_path(@post), headers: turbo_headers

    assert_equal 1, @post.reload.shares_count
    assert_equal 0, other_post.reload.shares_count
  end

  test "sharing changes nothing else about the post" do
    assert_no_difference [ "Like.count", "Bookmark.count", "Comment.count" ] do
      post post_share_path(@post), headers: turbo_headers
    end
  end

  test "without Turbo the post page is loaded again" do
    post post_share_path(@post)

    assert_response :see_other
    assert_redirected_to post_page_path_for(@post)
    assert_equal 1, @post.reload.shares_count
  end

  test "a post that does not exist gives a 404" do
    post post_share_path(0), headers: turbo_headers

    assert_response :not_found
  end
end
