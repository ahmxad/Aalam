require "test_helper"

class SlugRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @topic = Admin::Topic.create!(title: "Original Topic", image: sample_image)
    @card = Admin::Card.create!(title: "Original Card", topic: @topic, image: sample_image)
    @post = Admin::Post.create!(title: "Original Post", summary: "A summary", body: "A body", card: @card)

    @old_topic_slug = @topic.slug
    @old_card_slug = @card.slug
    @old_post_slug = @post.slug
  end

  test "a renamed topic redirects its old URL permanently" do
    @topic.update!(title: "Renamed Topic")

    get topic_path(@old_topic_slug)

    assert_response :moved_permanently
    assert_redirected_to topic_path(@topic.slug)
  end

  test "a renamed card redirects its old URL permanently" do
    @card.update!(title: "Renamed Card")

    get topic_card_path(@topic.slug, @old_card_slug)

    assert_response :moved_permanently
    assert_redirected_to topic_card_path(@topic.slug, @card.slug)
  end

  test "a renamed post redirects its old URL permanently" do
    @post.update!(title: "Renamed Post")

    get topic_card_post_path(@topic.slug, @card.slug, @old_post_slug)

    assert_response :moved_permanently
    assert_redirected_to topic_card_post_path(@topic.slug, @card.slug, @post.slug)
  end

  test "an old URL redirects even when every level was renamed" do
    @topic.update!(title: "Renamed Topic")
    @card.update!(title: "Renamed Card")
    @post.update!(title: "Renamed Post")

    get topic_card_post_path(@old_topic_slug, @old_card_slug, @old_post_slug)

    assert_response :moved_permanently
    assert_redirected_to topic_card_post_path(@topic.slug, @card.slug, @post.slug)
  end

  test "a card page under an old topic slug redirects to the new topic slug" do
    @topic.update!(title: "Renamed Topic")

    get topic_card_path(@old_topic_slug, @card.slug)

    assert_response :moved_permanently
    assert_redirected_to topic_card_path(@topic.slug, @card.slug)
  end

  test "every old slug in a chain of renames redirects to the current one" do
    @topic.update!(title: "Second Name")
    @topic.update!(title: "Third Name")

    get topic_path(@old_topic_slug)
    assert_redirected_to topic_path("third-name")

    get topic_path("second-name")
    assert_redirected_to topic_path("third-name")
  end

  test "a card that moved to another topic redirects from its old URL" do
    other_topic = Admin::Topic.create!(title: "Other Topic", image: sample_image)
    @card.update!(topic: other_topic)

    get topic_card_path(@old_topic_slug, @old_card_slug)

    assert_response :moved_permanently
    assert_redirected_to topic_card_path(other_topic.slug, @card.slug)
  end

  test "renaming back to the original title serves the original URL without a redirect" do
    @topic.update!(title: "Renamed Topic")
    @topic.update!(title: "Original Topic")

    get topic_path(@old_topic_slug)
    assert_response :success

    get topic_path("renamed-topic")
    assert_response :moved_permanently
    assert_redirected_to topic_path(@old_topic_slug)
  end

  test "a record that now owns an old slug wins over the redirect" do
    @topic.update!(title: "Renamed Topic")
    newer = Admin::Topic.create!(title: "Original Topic", image: sample_image)

    get topic_path(@old_topic_slug)

    assert_response :success
    assert_select "h1", text: newer.title
  end

  test "the old URL of a deleted record returns 404" do
    @topic.update!(title: "Renamed Topic")
    @topic.destroy!

    get topic_path(@old_topic_slug)

    assert_response :not_found
  end

  test "an unknown slug still returns 404" do
    get topic_path("never-existed")

    assert_response :not_found
  end
end
