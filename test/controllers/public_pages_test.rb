require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  setup do
    @topic = Admin::Topic.create!(title: "Public Topic", image: sample_image)
    @card = Admin::Card.create!(title: "Public Card", topic: @topic, image: sample_image)
    @post = Admin::Post.create!(
      title: "Public Post",
      summary: "A short summary",
      body: "The full body text",
      card: @card
    )
  end

  # --- Pages render with the right content ---

  test "explore lists a topic" do
    get explore_url

    assert_response :success
    assert_select "h2", text: @topic.title
  end

  test "topic page shows the topic and its cards" do
    get topic_url(@topic)

    assert_response :success
    assert_select "h1", text: @topic.title
    assert_select "h2", text: @card.title
  end

  test "card page shows the card and its posts" do
    get topic_card_url(@topic.slug, @card.slug)

    assert_response :success
    assert_select "h1", text: @card.title
    assert_select "h2", text: @post.title
  end

  test "post page shows the title, summary and body" do
    get topic_card_post_url(@topic.slug, @card.slug, @post.slug)

    assert_response :success
    assert_select "h1", text: @post.title
    assert_select "article", text: /A short summary/
    assert_select "article", text: /The full body text/
  end

  # --- Previous / next navigation ---

  test "post page links to the previous and next post in the same card" do
    first, second, third = %w[First Second Third].map do |name|
      Admin::Post.create!(title: "#{name} Nav Post", summary: "s", body: "b", card: @card)
    end

    get topic_card_post_url(@topic.slug, @card.slug, second.slug)

    assert_select "a[href=?]", topic_card_post_path(@topic.slug, @card.slug, first.slug)
    assert_select "a[href=?]", topic_card_post_path(@topic.slug, @card.slug, third.slug)
  end

  test "the first post has no previous link and the last has no next link" do
    first = @post
    last = Admin::Post.create!(title: "Last Nav Post", summary: "s", body: "b", card: @card)

    get topic_card_post_url(@topic.slug, @card.slug, first.slug)
    assert_select "a", text: /Previous/, count: 0
    assert_select "a", text: /Next/, count: 1

    get topic_card_post_url(@topic.slug, @card.slug, last.slug)
    assert_select "a", text: /Next/, count: 0
    assert_select "a", text: /Previous/, count: 1
  end

  # --- Bad slugs return 404 ---

  test "unknown topic slug returns 404" do
    get topic_url("no-such-topic")
    assert_response :not_found
  end

  test "unknown card slug returns 404" do
    get topic_card_url(@topic.slug, "no-such-card")
    assert_response :not_found
  end

  test "unknown post slug returns 404" do
    get topic_card_post_url(@topic.slug, @card.slug, "no-such-post")
    assert_response :not_found
  end

  test "a card is not reachable under a different topic" do
    other_topic = Admin::Topic.create!(title: "Other Topic", image: sample_image)

    get topic_card_url(other_topic.slug, @card.slug)
    assert_response :not_found
  end
end
