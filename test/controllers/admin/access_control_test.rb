require "test_helper"

class Admin::AccessControlTest < ActionDispatch::IntegrationTest
  setup do
    @topic = admin_topics(:one)
    @card = admin_cards(:one)
    @post = admin_posts(:one)
  end

  # --- Not logged in ---

  test "guest is redirected to login from the dashboard" do
    get admin_root_url
    assert_redirected_to new_session_url
  end

  test "guest is redirected to login from every admin index page" do
    [ admin_topics_url, admin_cards_url, admin_posts_url ].each do |url|
      get url
      assert_redirected_to new_session_url, "expected #{url} to require login"
    end
  end

  test "guest cannot create a topic" do
    assert_no_difference("Admin::Topic.count") do
      post admin_topics_url, params: {
        admin_topic: { title: "Guest Topic", image: fixture_file_upload("test.png", "image/png") }
      }
    end
    assert_redirected_to new_session_url
  end

  test "guest cannot delete a topic, card or post" do
    assert_no_difference([ "Admin::Topic.count", "Admin::Card.count", "Admin::Post.count" ]) do
      delete admin_topic_url(@topic)
      delete admin_card_url(@card)
      delete admin_post_url(@post)
    end
  end

  # --- Logged in, but not an admin (fixture user has admin: nil) ---

  test "non-admin is redirected to the home page from admin pages" do
    sign_in_as(users(:one))

    [ admin_root_url, admin_topics_url, admin_cards_url, admin_posts_url ].each do |url|
      get url
      assert_redirected_to root_url, "expected #{url} to be admin only"
    end
  end

  test "non-admin cannot create a topic" do
    sign_in_as(users(:one))

    assert_no_difference("Admin::Topic.count") do
      post admin_topics_url, params: {
        admin_topic: { title: "Non Admin Topic", image: fixture_file_upload("test.png", "image/png") }
      }
    end
    assert_redirected_to root_url
  end

  test "non-admin cannot delete a topic, card or post" do
    sign_in_as(users(:one))

    assert_no_difference([ "Admin::Topic.count", "Admin::Card.count", "Admin::Post.count" ]) do
      delete admin_topic_url(@topic)
      delete admin_card_url(@card)
      delete admin_post_url(@post)
    end
  end

  # --- Public pages stay open ---

  test "public pages do not require login" do
    [ root_url, explore_url, about_url, contact_url ].each do |url|
      get url
      assert_response :success, "expected #{url} to be public"
    end
  end
end
