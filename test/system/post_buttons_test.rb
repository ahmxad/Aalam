require "application_system_test_case"

class PostButtonsTest < ApplicationSystemTestCase
  setup do
    @post = create_post
    @user = users(:one)
  end

  test "Like and Save change in place, without loading the page again" do
    log_in_as(@user)
    visit post_page_path_for(@post)
    wait_for_controller("comments-modal")
    execute_script("window.pageStillTheSame = true")

    find("button[aria-label='Like (0)']").click
    assert_selector "button[aria-label='Liked (1)'][aria-pressed='true']"

    find("button[aria-label='Save (0)']").click
    assert_selector "button[aria-label='Saved (1)'][aria-pressed='true']"

    find("button[aria-label='Liked (1)']").click
    assert_selector "button[aria-label='Like (0)'][aria-pressed='false']"

    assert evaluate_script("window.pageStillTheSame"), "the page was loaded again"
    assert_equal 0, @post.reload.likes_count
    assert_equal 1, @post.bookmarks_count
  end

  test "a visitor who presses Like logs in and comes back to the post" do
    visit post_page_path_for(@post)
    wait_for_controller("comments-modal")
    find("button[aria-label='Like (0)']").click

    assert_current_path new_session_path
    assert_text "Please log in to continue."

    fill_in "login", with: @user.username
    fill_in "password", with: "password"
    click_button "Log in"

    assert_current_path post_page_path_for(@post)
    assert_selector "button[aria-label='Like (0)']"
    assert_equal 0, @post.reload.likes_count
  end

  test "Share copies the link and counts the share" do
    visit post_page_path_for(@post)
    wait_for_controller("share")
    # Headless Chrome may refuse to touch the clipboard, so the browser's own copy is replaced by one that records the text
    execute_script(<<~JS)
      Object.defineProperty(navigator, "clipboard", {
        configurable: true,
        value: { writeText: (text) => { window.copiedText = text; return Promise.resolve() } }
      })
    JS

    find("button[aria-label='Share']").click

    assert_text "Link copied"
    assert evaluate_script("window.copiedText").end_with?(post_page_path_for(@post))
    assert_selector "##{dom_id(@post, :shares_count)}", text: "1"
    assert_equal 1, @post.reload.shares_count
  end

  test "a saved post is removed from the list on the profile, after the browser asks to confirm" do
    Bookmark.create!(user: @user, post: @post)
    log_in_as(@user)
    visit profile_path(@user.username)

    within "#saved-posts" do
      assert_text @post.title
      assert_equal [ "Remove this post from your saved posts?" ], click_and_accept_confirm("Remove")
      assert_text "You have not saved any posts yet."
      assert_no_text @post.title
    end

    assert_equal 0, @post.reload.bookmarks_count
  end
end
