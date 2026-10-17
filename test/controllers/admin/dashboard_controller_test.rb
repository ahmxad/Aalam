
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "dashboard-admin@test.com",
      password: "password123!",
      admin: true
    )
    sign_in_as(@user)
  end

  test "should get index" do
    get admin_root_url
    assert_response :success
  end
  test "shows a card for each section with its total" do
    get admin_root_url

    assert_select "a.surface-card", count: 3
    assert_select "a.surface-card[href='#{admin_topics_path}'] .text-4xl", text: Admin::Topic.count.to_s
    assert_select "a.surface-card[href='#{admin_cards_path}'] .text-4xl", text: Admin::Card.count.to_s
    assert_select "a.surface-card[href='#{admin_posts_path}'] .text-4xl", text: Admin::Post.count.to_s
  end

  test "has quick links to create a topic, a card and a post" do
    get admin_root_url

    assert_select "a[href='#{new_admin_topic_path}']"
    assert_select "a[href='#{new_admin_card_path}']"
    assert_select "a[href='#{new_admin_post_path}']"
  end

  test "lists the recently changed posts with a link to edit each one" do
    get admin_root_url

    assert_select ".surface-row", count: [ Admin::Post.count, 5 ].min

    post_record = Admin::Post.order(updated_at: :desc).first
    assert_select "a[href='#{edit_admin_post_path(post_record)}']"
  end

  test "shows a message instead of the list when there are no posts" do
    Admin::Post.destroy_all

    get admin_root_url

    assert_select ".surface-row", count: 0
    assert_select "p", text: /No posts yet/
  end
end
