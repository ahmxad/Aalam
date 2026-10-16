require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  setup do
    @topic = Admin::Topic.create!(title: "Search Home Topic", image: sample_image)
    @card = Admin::Card.create!(title: "Search Home Card", topic: @topic, image: sample_image)
  end

  # --- Matching ---

  test "search ignores letter case" do
    get search_url, params: { q: "SEARCH HOME TOPIC" }

    assert_response :success
    assert_select "h3", text: "Search Home Topic"
  end

  test "search finds a post by its summary" do
    Admin::Post.create!(title: "Plain Title", summary: "Mentions zebracrossing here", body: "A body", card: @card)

    get search_url, params: { q: "zebracrossing" }

    assert_select "h3", text: "Plain Title"
  end

  test "search finds a post by its body" do
    Admin::Post.create!(title: "Another Title", summary: "A summary", body: "Deep inside quokkaland lives", card: @card)

    get search_url, params: { q: "quokkaland" }

    assert_select "h3", text: "Another Title"
  end

  test "topic results are sorted by title" do
    now = Time.current
    Admin::Topic.insert_all([
      { title: "Sorted Zeta", slug: "sorted-zeta", created_at: now, updated_at: now },
      { title: "Sorted Alpha", slug: "sorted-alpha", created_at: now, updated_at: now }
    ])

    get search_url, params: { q: "Sorted" }

    titles = css_select("article h3").map { |node| node.text.strip }
    assert_equal [ "Sorted Alpha", "Sorted Zeta" ], titles
  end

  # --- Wildcards are searched literally ---

  test "a percent sign is searched literally, not as a wildcard" do
    get search_url, params: { q: "%" }

    assert_select "p", text: "No results found."
  end

  test "an underscore is searched literally, not as a single character wildcard" do
    get search_url, params: { q: "Search Hom_ Topic" }

    assert_select "p", text: "No results found."
  end

  # --- Limits ---

  test "topic results are capped and the page says so" do
    now = Time.current
    Admin::Topic.insert_all(
      Array.new(PagesController::SEARCH_LIMIT + 1) do |i|
        { title: "Bulk Topic #{i}", slug: "bulk-topic-#{i}", created_at: now, updated_at: now }
      end
    )

    get search_url, params: { q: "Bulk Topic" }

    assert_select "h3", text: /Bulk Topic/, count: PagesController::SEARCH_LIMIT
    assert_select "p", text: /Showing the first #{PagesController::SEARCH_LIMIT} results/
  end

  test "post results are capped" do
    now = Time.current
    Admin::Post.insert_all(
      Array.new(PagesController::SEARCH_LIMIT + 1) do |i|
        { card_id: @card.id, title: "Bulk Post #{i}", summary: "s", body: "b", slug: "bulk-post-#{i}", created_at: now, updated_at: now }
      end
    )

    get search_url, params: { q: "Bulk Post" }

    assert_select "h3", text: /Bulk Post/, count: PagesController::SEARCH_LIMIT
  end

  test "a very long query is cut to the maximum length" do
    long_query = "a" * (PagesController::MAX_QUERY_LENGTH + 50)

    get search_url, params: { q: long_query }

    assert_response :success
    assert_includes response.body, "a" * PagesController::MAX_QUERY_LENGTH
    assert_not_includes response.body, "a" * (PagesController::MAX_QUERY_LENGTH + 1)
  end

  # --- Input handling ---

  test "a query of only spaces is treated as empty" do
    get search_url, params: { q: "   " }

    assert_response :success
    assert_select "p", text: "Please enter something to search."
  end

  test "html in the query is escaped" do
    get search_url, params: { q: "<script>alert(1)</script>" }

    assert_response :success
    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end
end
