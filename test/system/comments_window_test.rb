require "application_system_test_case"

class CommentsWindowTest < ApplicationSystemTestCase
  LIST = "dialog .overflow-y-auto".freeze

  setup do
    @post = create_post
    @user = users(:one)
    @admin = users(:two)
  end

  def visit_post
    visit post_page_path_for(@post)
    wait_for_controller("comments-modal")
  end

  def open_comments
    find("a[aria-label^='Comments']").click
    assert_selector "dialog[open]"
    assert_selector "dialog h2", text: "Comments"
  end

  # Opening and closing

  test "the window opens over the post and closes with the cross and with a click on the dimmed area" do
    log_in_as(@user)
    visit_post
    assert_no_selector "dialog[open]"

    open_comments
    assert_text "No comments yet."
    find("button[aria-label='Close comments']").click
    assert_no_selector "dialog[open]"

    open_comments
    # A click on the dimmed area is a click whose target is the dialog itself
    execute_script("document.querySelector('dialog[open]').dispatchEvent(new MouseEvent('click', { bubbles: true }))")
    assert_no_selector "dialog[open]"
  end

  test "a visitor can read the comments" do
    create_comment(@post, "Readable by everyone", user: @admin)
    visit_post

    open_comments

    assert_selector "dialog #comments_list li", text: "Readable by everyone"
  end

  # Writing

  test "a comment written in the window appears at once and updates both counts" do
    log_in_as(@user)
    visit_post
    open_comments

    within("#comment_form") do
      fill_in "comment[body]", with: "A comment from the browser"
      click_button "Post"
    end

    assert_selector "dialog #comments_list li", text: "A comment from the browser"
    assert_no_text "No comments yet."
    assert_selector "dialog #comments_count", text: "1"
    assert_field "comment[body]", with: ""
    assert_selector "a[aria-label='Comments (1)']"
    assert_equal 1, @post.reload.comments_count
  end

  test "a visitor who posts is taken to the log in page, out of the window" do
    visit_post
    open_comments

    within("#comment_form") do
      fill_in "comment[body]", with: "Written before logging in"
      click_button "Post"
    end

    assert_current_path new_session_path
    assert_text "Please log in to continue."
    assert_equal 0, Comment.count
  end

  test "someone who has not verified their email is taken to verify it, out of the window" do
    person = create_unverified_user("unverified_commenter")
    log_in_as(person, password: "password123")
    visit_post
    open_comments

    within("#comment_form") do
      fill_in "comment[body]", with: "Written too early"
      click_button "Post"
    end

    assert_current_path email_verification_path
    assert_text "Verify your email first"
    assert_equal 0, Comment.count
  end

  # Replies, hearts and delete

  test "a reply is written under a comment and its replies open" do
    comment = create_comment(@post, "Top comment", user: @admin)
    log_in_as(@user)
    visit_post
    open_comments

    within("##{dom_id(comment)}") do
      find("summary", text: "Reply").click
      fill_in "comment[body]", with: "A reply from the browser"
      click_button "Reply"
    end

    assert_selector "##{dom_id(comment)}", text: "A reply from the browser"
    assert_selector "##{dom_id(comment)}", text: "1 reply"
    assert_selector "dialog #comments_count", text: "2"
    assert_equal 1, comment.reload.replies_count
  end

  test "the heart under a comment turns on and off, with its count" do
    comment = create_comment(@post, "Likeable", user: @admin)
    log_in_as(@user)
    visit_post
    open_comments

    find("dialog button[aria-label='Like (0)']").click
    assert_selector "dialog button[aria-label='Unlike (1)'][aria-pressed='true']"
    assert_equal 1, comment.reload.likes_count

    find("dialog button[aria-label='Unlike (1)']").click
    assert_selector "dialog button[aria-label='Like (0)'][aria-pressed='false']"
    assert_equal 0, comment.reload.likes_count
  end

  test "the author deletes their comment after the browser asks to confirm" do
    comment = create_comment(@post, "To be deleted", user: @user)
    log_in_as(@user)
    visit_post
    open_comments

    within("##{dom_id(comment)}") do
      assert_equal [ "Delete this comment and its replies?" ], click_and_accept_confirm("Delete")
    end

    assert_no_selector "##{dom_id(comment)}"
    assert_selector "dialog #comments_count", text: "0"
    assert_selector "a[aria-label='Comments (0)']"
    assert_equal 0, @post.reload.comments_count
  end

  # Many comments

  test "ten comments show at first and Load more brings the rest" do
    Array.new(12) { |index| create_comment(@post, "Comment number #{index}") }
    visit_post

    open_comments
    assert_selector "dialog li[id^='comment_']", count: 10

    click_link "Load more comments"

    assert_selector "dialog li[id^='comment_']", count: 12
    assert_no_link "Load more comments"
  end

  test "the tabs change the order, and Latest brings the newest back to the top" do
    create_comment(@post, "Quiet comment")
    busy = create_comment(@post, "Busy comment")
    create_comment(@post, "Newest comment")
    2.times { create_comment(@post, "A reply", parent: busy) }
    visit_post
    open_comments

    assert_selector "#comments_list > li:first-child", text: "Newest comment"

    within("dialog") { click_link "Most replies" }
    assert_selector "a.tab-active", text: "Most replies"
    assert_selector "#comments_list > li:first-child", text: "Busy comment"

    within("dialog") { click_link "Latest" }
    assert_selector "a.tab-active", text: "Latest"
    assert_selector "#comments_list > li:first-child", text: "Newest comment"
  end

  # The wheel

  # The most delicate test of the file: it sends a real mouse wheel to the browser and needs a window
  # that is small enough for the list to scroll
  test "the mouse wheel scrolls the comments and not the page behind them" do
    Array.new(10) { |index| create_comment(@post, "Comment number #{index} #{"words " * 20}") }
    visit_post

    begin
      page.driver.browser.manage.window.resize_to(1000, 600)
      open_comments

      box = find(LIST)
      script = "document.querySelector('#{LIST}')"
      assert_operator evaluate_script("#{script}.scrollHeight"), :>, evaluate_script("#{script}.clientHeight"),
                      "the list must be taller than its window, or this test shows nothing"

      rect = box.native.rect
      page.driver.browser.execute_cdp(
        "Input.dispatchMouseEvent",
        type: "mouseWheel",
        x: (rect.x + rect.width / 2).to_i, y: (rect.y + rect.height / 2).to_i,
        deltaX: 0, deltaY: 300
      )

      wait_for("the list should have scrolled") { evaluate_script("#{script}.scrollTop") > 0 }
      assert_equal 0, evaluate_script("window.scrollY")
    ensure
      page.driver.browser.manage.window.resize_to(1400, 1400)
    end
  end
end
