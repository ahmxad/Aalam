require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

class SavedPostsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @user = users(:one)
    @other = users(:two)
    @card = create_card
    sign_in_as(@user)
  end

  # A post in the card that the given user has saved
  def save_post(title = "Saved #{SecureRandom.hex(3)}", user: @user)
    created = create_post(card: @card, title: title)
    Bookmark.create!(user: user, post: created)
    created
  end

  def open_saved(params = {})
    get saved_posts_path(**params), headers: frame_headers("saved_posts")
  end

  def row_ids
    css_select("#saved_posts_list li").map { |item| item["id"] }
  end

  # Who can see the list

  test "a visitor who is not signed in is sent to log in" do
    delete session_path

    get saved_posts_path

    assert_redirected_to new_session_path
  end

  test "the list shows the posts the signed in user saved, the newest save first" do
    first = save_post("First saved")
    second = save_post("Second saved")

    open_saved

    assert_response :success
    assert_select "turbo-frame#saved_posts"
    assert_equal [ dom_id(second, :saved), dom_id(first, :saved) ], row_ids
  end

  test "what other people saved is never shown" do
    mine = save_post("My saved post")
    save_post("Secret saved post", user: @other)

    open_saved

    assert_equal [ dom_id(mine, :saved) ], row_ids
    assert_not_includes response.body, "Secret saved post"
  end

  test "there is no way to ask for the list of someone else" do
    mine = save_post("My saved post")
    save_post("Secret saved post", user: @other)

    open_saved(user_id: @other.id, username: @other.username, id: @other.id)

    assert_equal [ dom_id(mine, :saved) ], row_ids
    assert_not_includes response.body, "Secret saved post"
  end

  # What a row shows

  test "a row shows where the post is, a link to it, its summary and a Remove button" do
    saved = save_post("Readable title")

    open_saved

    assert_select "li##{dom_id(saved, :saved)}" do
      assert_select "p", "#{@card.topic.title} / #{@card.title}"
      assert_select "a[href=?][data-turbo-frame=_top]", post_page_path_for(saved), text: "Readable title"
      assert_select "p", "A short summary"
      assert_select "p", /Saved .* ago/
      assert_select "form[action=?]", post_bookmark_path(saved, from: "saved") do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", "Remove"
      end
    end
  end

  test "the empty message shows only when nothing is saved" do
    open_saved
    assert_select "#saved_posts_empty:not(.hidden)", text: /not saved any posts/

    save_post
    open_saved
    assert_select "#saved_posts_empty.hidden"
  end

  # Staying in step with the buttons

  test "the list follows the Save button on the post page" do
    to_save = create_post(card: @card)

    post post_bookmark_path(to_save), headers: turbo_headers
    open_saved
    assert_equal [ dom_id(to_save, :saved) ], row_ids

    delete post_bookmark_path(to_save, from: "saved"), headers: turbo_headers
    open_saved
    assert_empty row_ids
  end

  test "a post that is deleted leaves the list" do
    keep = save_post("Stays")
    gone = save_post("Goes")

    gone.destroy
    open_saved

    assert_equal [ dom_id(keep, :saved) ], row_ids
  end

  # Load more

  test "ten posts are shown at first and Load more brings the rest" do
    posts = Array.new(12) { |index| create_post(card: @card, title: "Saved #{index}") }
    bookmarks = posts.map { |saved| Bookmark.create!(user: @user, post: saved) }

    open_saved
    assert_equal posts.reverse.first(10).map { |saved| dom_id(saved, :saved) }, row_ids

    cursor = bookmarks[2].id
    assert_select "turbo-frame#saved_more_#{cursor} a[href=?]", saved_posts_path(cursor: cursor), text: "Load more"

    get saved_posts_path(cursor: cursor), headers: frame_headers("saved_more_#{cursor}")

    assert_response :success
    rest = css_select("turbo-frame#saved_more_#{cursor} li").map { |item| item["id"] }
    assert_equal [ dom_id(posts[1], :saved), dom_id(posts[0], :saved) ], rest
    assert_select "a", text: "Load more", count: 0
  end

  test "exactly ten posts need no Load more" do
    Array.new(10) { save_post }

    open_saved

    assert_equal 10, row_ids.size
    assert_select "a", text: "Load more", count: 0
  end

  test "the next batch never contains saves of other people" do
    posts = Array.new(11) { |index| create_post(card: @card, title: "Saved #{index}") }
    bookmarks = posts.map { |saved| Bookmark.create!(user: @user, post: saved) }
    save_post("Secret saved post", user: @other)

    get saved_posts_path(cursor: bookmarks[0].id + 1), headers: frame_headers("saved_more_#{bookmarks[0].id + 1}")

    assert_not_includes response.body, "Secret saved post"
  end

  test "a broken cursor shows the list from the start instead of failing" do
    saved = save_post

    open_saved(cursor: "garbage")

    assert_response :success
    assert_equal [ dom_id(saved, :saved) ], row_ids
  end
end

class ProfileSavedSectionTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @owner = users(:one)
    @visitor = users(:two)
    @saved = create_post(title: "Private saved title")
    Bookmark.create!(user: @owner, post: @saved)
  end

  test "the owner sees the saved posts section, loaded from the private list" do
    sign_in_as(@owner)

    get profile_path(@owner.username)

    assert_select "main section#saved-posts" do
      assert_select "h2", "Saved posts"
      assert_select "p", "Only you can see this list."
      assert_select "turbo-frame#saved_posts[src=?]", saved_posts_path
    end
  end

  test "the saved posts themselves are not in the profile page, they come from the list" do
    sign_in_as(@owner)

    get profile_path(@owner.username)

    assert_not_includes response.body, "Private saved title"
  end

  test "another signed in user sees nothing of it on the profile of the owner" do
    sign_in_as(@visitor)

    get profile_path(@owner.username)

    assert_response :success
    assert_select "main #saved-posts", 0
    assert_select "main turbo-frame#saved_posts", 0
    assert_select "main", text: /Saved posts/, count: 0
    assert_not_includes css_select("main").to_html, saved_posts_path
    assert_not_includes response.body, "Private saved title"
  end

  test "a visitor who is not signed in sees nothing of it either" do
    get profile_path(@owner.username)

    assert_response :success
    assert_select "main #saved-posts", 0
    assert_select "main turbo-frame#saved_posts", 0
    assert_not_includes response.body, "Private saved title"
  end

  test "a user sees the section on their own profile, not on the one of the owner" do
    sign_in_as(@visitor)

    get profile_path(@visitor.username)
    assert_select "main section#saved-posts", 1

    get profile_path(@owner.username)
    assert_select "main section#saved-posts", 0
  end

  test "the profile menu links to the section for a signed in user" do
    sign_in_as(@owner)

    get root_path

    assert_select "header .dropdown-content a[href=?]", profile_path(@owner.username, anchor: "saved-posts"), text: "Saved posts"
  end

  test "a visitor who is not signed in has no such link" do
    get root_path

    assert_select "header a", text: "Saved posts", count: 0
  end
end
