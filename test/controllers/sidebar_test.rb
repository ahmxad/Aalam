require "test_helper"

class SidebarTest < ActionDispatch::IntegrationTest
  setup do
    @topic = Admin::Topic.create!(title: "Sidebar Alpha", image: sample_image)
    @card = Admin::Card.create!(title: "Sidebar Card", topic: @topic, image: sample_image)
    @other_topic = Admin::Topic.create!(title: "Sidebar Beta", image: sample_image)
    Admin::Card.create!(title: "Beta Card", topic: @other_topic, image: sample_image)
    @empty_topic = Admin::Topic.create!(title: "Sidebar Empty", image: sample_image)
  end

  test "public pages list every topic with a link, and its cards" do
    get root_url

    assert_select "aside#sidebar nav a[href='#{topic_path(@topic.slug)}']", text: "Sidebar Alpha"
    assert_select "aside#sidebar nav a[href='#{topic_card_path(@topic.slug, @card.slug)}']", text: "Sidebar Card"
    assert_select "aside#sidebar nav a[href='#{topic_path(@other_topic.slug)}']", text: "Sidebar Beta"
  end

  test "the list scrolls on its own and the smooth scroll library stays away from it" do
    get root_url

    assert_select "aside#sidebar nav[data-lenis-prevent]"
  end

  test "the sidebar stays in place when Turbo replaces the page" do
    get root_url

    assert_select "aside#sidebar[data-turbo-permanent]"
  end

  test "the topic being viewed is expanded and the others are collapsed" do
    get topic_url(@topic.slug)

    assert_select "button[aria-controls='sidebar-topic-#{@topic.id}'][aria-expanded='true']"
    assert_select "ul#sidebar-topic-#{@topic.id}:not([hidden])"
    assert_select "button[aria-controls='sidebar-topic-#{@other_topic.id}'][aria-expanded='false']"
    assert_select "ul#sidebar-topic-#{@other_topic.id}[hidden]"
  end

  test "the topic page itself is marked as current" do
    get topic_url(@topic.slug)

    assert_select "aside#sidebar a[href='#{topic_path(@topic.slug)}'][aria-current='page']"
  end

  test "a card page marks its card as current, not its topic" do
    get topic_card_url(@topic.slug, @card.slug)

    assert_select "aside#sidebar a[href='#{topic_card_path(@topic.slug, @card.slug)}'][aria-current='page']"
    assert_select "aside#sidebar a[href='#{topic_path(@topic.slug)}'][aria-current='page']", count: 0
  end

  test "a post page marks its card as current" do
    post_record = Admin::Post.create!(title: "Sidebar Post", summary: "s", body: "b", card: @card)

    get topic_card_post_url(@topic.slug, @card.slug, post_record.slug)

    assert_select "aside#sidebar a[href='#{topic_card_path(@topic.slug, @card.slug)}'][aria-current='page']"
  end

  test "a topic without cards has no dropdown button" do
    get root_url

    assert_select "button[aria-controls='sidebar-topic-#{@empty_topic.id}']", count: 0
  end

  test "the navbar has the button that shows and hides the sidebar" do
    get root_url

    assert_select "button[aria-controls='sidebar'][data-action='sidebar#toggle']"
  end

  test "a saved closed state is on the page itself, so it never flashes open" do
    cookies[:sidebar] = "closed"

    get root_url

    assert_select "html[data-sidebar='closed']"
  end

  test "an unknown saved value is ignored" do
    cookies[:sidebar] = "nonsense"

    get root_url

    assert_select "html[data-sidebar]", count: 0
  end

  test "the admin area has no sidebar and no button for it" do
    sign_in_as(User.create!(email_address: "sidebar-admin@test.com", password: "password123!", admin: true))

    get admin_root_url

    assert_select "aside#sidebar", count: 0
    assert_select "button[aria-controls='sidebar']", count: 0
  end

  test "error pages have no sidebar" do
    get "/404"

    assert_response :not_found
    assert_select "aside#sidebar", count: 0
  end
    test "the navbar has the element the sidebar script measures" do
    get root_url

    assert_select "header#site-header"
  end

  test "the sidebar list reacts to clicks, and the sidebar has its own close button" do
    get root_url

    assert_select "aside#sidebar nav.sidebar__scroll[data-action='click->sidebar#select']"
    assert_select "aside#sidebar button.sidebar__close[data-action='sidebar#toggle']"
  end

  test "pages with the sidebar share its starting line, other pages do not" do
    get root_url
    assert_select "div.app-shell--with-sidebar"

    get "/404"
    assert_select "div.app-shell"
    assert_select "div.app-shell--with-sidebar", count: 0
  end
end
