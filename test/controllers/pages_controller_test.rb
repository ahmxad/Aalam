require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get home_url
    assert_response :success
  end

  test "should get contact" do
    get contact_url
    assert_response :success
  end

  test "should get explore" do
    get explore_url
    assert_response :success
  end
  test "search finds a topic without cards or posts" do
    topic = Admin::Topic.create!(title: "Standalone Topic")

    get search_url, params: { q: topic.title }

    assert_response :success
    assert_select "h3", text: topic.title
    assert_select "a", text: "View Topic"
  end

  test "search finds a card and displays its topic" do
    topic = Admin::Topic.create!(title: "Search Test Topic")
    card = Admin::Card.create!(
      title: "Unique Search Card",
      topic: topic
    )

    get search_url, params: { q: card.title }

    assert_response :success
    assert_select "h3", text: card.title
    assert_select "a", text: "View Card"
    assert_select "a", text: topic.title
  end

  test "search finds a post and displays its hierarchy" do
    topic = Admin::Topic.create!(title: "Post Search Topic")
    card = Admin::Card.create!(
      title: "Post Search Card",
      topic: topic
    )
    post = Admin::Post.create!(
      title: "Unique Search Post",
      summary: "A test summary",
      body: "A test body",
      card: card
    )

    get search_url, params: { q: post.title }

    assert_response :success
    assert_select "h3", text: post.title
    assert_select "a", text: "Read Post"
    assert_select "a", text: topic.title
    assert_select "a", text: card.title
  end

  test "search shows no results for an unmatched query" do
    get search_url, params: { q: "NoMatchingContentXYZ" }

    assert_response :success
    assert_select "p", text: "No results found."
  end

  test "search page loads with a blank query" do
    get search_url, params: { q: "" }

    assert_response :success
    assert_select "p", text: "Please enter something to search."
  end
end
