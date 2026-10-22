require "test_helper"
require_relative "../support/post_builder"

class PostPageActionsTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder

  setup do
    @post = create_post
    @user = users(:one)
  end

  def actions
    "##{dom_id(@post, :actions)}"
  end

  def open_post
    get post_page_path_for(@post)
  end

  test "a guest sees Like, Comments, Share and Save with their counts" do
    open_post

    assert_response :success
    assert_select "#{actions} button[aria-label=?]", "Like (0)"
    assert_select "#{actions} a[aria-label=?]", "Comments (0)"
    assert_select "#{actions} button[aria-label=?]", "Share"
    assert_select "#{actions} button[aria-label=?]", "Save (0)"
    assert_select "#{actions} button[aria-pressed=true]", 0
  end

  test "a signed in user sees the same buttons" do
    sign_in_as(@user)

    open_post

    assert_response :success
    assert_select "#{actions} button[aria-label=?]", "Like (0)"
    assert_select "#{actions} a[aria-label=?]", "Comments (0)"
    assert_select "#{actions} button[aria-label=?]", "Share"
    assert_select "#{actions} button[aria-label=?]", "Save (0)"
  end

  test "the counts come from the database" do
    Like.create!(user: users(:one), likeable: @post)
    Like.create!(user: users(:two), likeable: @post)
    Bookmark.create!(user: users(:one), post: @post)
    top = create_comment(@post, "Top")
    create_comment(@post, "Reply", parent: top)
    Admin::Post.increment_counter(:shares_count, @post.id, by: 4)

    open_post

    assert_select "#{actions} button[aria-label=?]", "Like (2)"
    assert_select "#{actions} a[aria-label=?]", "Comments (2)"
    assert_select "#{actions} button[aria-label=?]", "Save (1)"
    assert_select "##{dom_id(@post, :shares_count)}", "4"
  end

  test "big numbers are written with a separator" do
    @post.update_columns(likes_count: 1234)

    open_post

    assert_select "#{actions} button[aria-label=?] span.tabular-nums", "Like (1234)", text: "1,234"
  end

  test "the engagement of another post does not show here" do
    other = create_post(card: @post.card)
    Like.create!(user: @user, likeable: other)
    Bookmark.create!(user: @user, post: other)

    open_post

    assert_select "#{actions} button[aria-label=?]", "Like (0)"
    assert_select "#{actions} button[aria-label=?]", "Save (0)"
  end

  test "a like by someone else is not shown as mine" do
    Like.create!(user: users(:two), likeable: @post)
    sign_in_as(@user)

    open_post

    assert_select "#{actions} button[aria-pressed=true]", 0
    assert_select "#{actions} button[aria-label=?]", "Like (1)"
  end

  test "my own like and save are shown as pressed" do
    Like.create!(user: @user, likeable: @post)
    Bookmark.create!(user: @user, post: @post)
    sign_in_as(@user)

    open_post

    assert_select "#{actions} button[aria-pressed=true]", 2
    assert_select "#{actions} button[aria-label=?]", "Liked (1)"
    assert_select "#{actions} button[aria-label=?]", "Saved (1)"
  end

  test "Like and Save send their request to this post" do
    open_post

    assert_select "#{actions} form[method=post][action=?]", post_like_path(@post)
    assert_select "#{actions} form[method=post][action=?]", post_bookmark_path(@post)
  end

  test "the Comments button opens the comments window" do
    open_post

    assert_select "#{actions} a[href=?][data-turbo-frame=comments_panel]", post_comments_path(@post)
    assert_select "#{actions} a[data-action=?]", "click->comments-modal#open"
  end

  test "Share knows the full address and title of the post and reports a successful share" do
    open_post
    url = topic_card_post_url(@post.card.topic.slug, @post.card.slug, @post.slug)

    assert_select "#{actions} [data-controller=share][data-share-url-value=?][data-share-title-value=?]", url, @post.title
    assert_select "#{actions} form[hidden][action=?]", post_share_path(@post)
  end

  test "the comments window is on the page but empty until it is opened" do
    create_comment(@post, "Only in the window")

    open_post

    assert_select "[data-controller=comments-modal] dialog.modal[aria-label=Comments]", 1
    assert_select "dialog turbo-frame#comments_panel:not([src])", text: /Loading comments/
    assert_not_includes response.body, "Only in the window"
  end

  test "the buttons sit under the article and above Keep reading" do
    create_post(card: @post.card)

    open_post

    body = response.body
    article_end = body.index("</article>")
    buttons = body.index(dom_id(@post, :actions))
    keep_reading = body.index("Keep reading")

    assert article_end && buttons && keep_reading
    assert_operator article_end, :<, buttons
    assert_operator buttons, :<, keep_reading
  end
end
