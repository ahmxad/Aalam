require "test_helper"
require_relative "../support/post_builder"

# Like, Comments, Share and Save belong on the post page only, with their counts
class EngagementOnlyOnPostPageTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @post = create_post(title: "Findable engagement post")
    @card = @post.card
    @topic = @card.topic
    @user = users(:one)

    # The post has engagement, so a page that showed any of it would have something to show
    Like.create!(user: @user, likeable: @post)
    Bookmark.create!(user: @user, post: @post)
    create_comment(@post, "Visible only in the window")
    Admin::Post.increment_counter(:shares_count, @post.id)
  end

  def public_pages
    {
      "home" => root_path,
      "home (second address)" => home_path,
      "explore" => explore_path,
      "about" => about_path,
      "contact" => contact_path,
      "search results" => search_path(q: "Findable engagement"),
      "topic" => topic_path(@topic.slug),
      "card" => topic_card_path(@topic.slug, @card.slug),
      "profile" => profile_path(@user.username),
      "log in" => new_session_path,
      "sign up" => signup_path,
      "error page" => "/404"
    }
  end

  def admin_pages
    {
      "admin dashboard" => admin_root_path,
      "admin posts" => admin_posts_path,
      "a post in admin" => admin_post_path(@post),
      "edit a post in admin" => edit_admin_post_path(@post),
      "new post in admin" => new_admin_post_path
    }
  end

  def assert_no_engagement_controls(path, label)
    get path

    assert_operator response.status, :<, 500, "#{label} should open"
    body = response.body

    %w[like bookmark share comments].each do |name|
      assert_no_match %r{/posts/#{@post.id}/#{name}}, body, "#{label} should not link to #{name}"
    end
    assert_no_match(/aria-label="(Like|Liked|Save|Saved|Comments|Share)( \(\d+\))?"/, body, "#{label} should have no engagement buttons")
    assert_select "dialog[aria-label=Comments]", 0, "#{label} should have no comments window"
    assert_select "[data-controller~=comments-modal]", 0, "#{label} should not load the comments window"
    assert_select "[data-controller~=share]", 0, "#{label} should not load the share button"
    assert_select "turbo-frame#comments_panel", 0, "#{label} should not have the comments frame"
    assert_not_includes body, "Visible only in the window", "#{label} should not show comments"
  end

  test "the post page itself has the controls, so the checks below mean something" do
    get post_page_path_for(@post)

    %w[like bookmark share comments].each do |name|
      assert_match %r{/posts/#{@post.id}/#{name}}, response.body
    end
    assert_select "dialog[aria-label=Comments]", 1
    assert_select "[data-controller~=share]", 1
  end

  test "no other page shows them to a visitor who is not signed in" do
    public_pages.each { |label, path| assert_no_engagement_controls(path, label) }
  end

  test "no other page shows them to a signed in user" do
    sign_in_as(@user)

    public_pages.each { |label, path| assert_no_engagement_controls(path, label) }
  end

  test "the admin pages do not show them to an admin" do
    sign_in_as(users(:two))

    admin_pages.each { |label, path| assert_no_engagement_controls(path, label) }
  end
end
