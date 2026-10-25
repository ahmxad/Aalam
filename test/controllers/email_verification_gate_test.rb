require "test_helper"
require_relative "../support/post_builder"
require_relative "../support/turbo_helpers"

# What someone who has not verified their email address can and cannot do
class EmailVerificationGateTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include PostBuilder
  include TurboHelpers

  setup do
    @post = create_post
    @author = users(:one)
    @comment = create_comment(@post, "Existing comment", user: @author)
    @person = create_unverified_user("gate_user")
    sign_in_as(@person)
  end

  # The page that holds the buttons, which is where a refused press has to lead back to
  def from_post_page
    { "Referer" => "http://www.example.com#{post_page_path_for(@post)}" }
  end

  def assert_sent_to_verify
    assert_response :see_other
    assert_redirected_to email_verification_path
    assert_equal "Verify your email first. Then you can like, save and comment.", flash[:alert]
  end

  # What is refused

  test "pressing Like or Save sends the user to verify and changes nothing" do
    assert_no_difference [ "Like.count", "Bookmark.count" ] do
      post post_like_path(@post), headers: turbo_headers(from_post_page)
      assert_sent_to_verify

      post post_bookmark_path(@post), headers: turbo_headers(from_post_page)
      assert_sent_to_verify
    end
  end

  test "undoing a like or a save is refused too" do
    delete post_like_path(@post), headers: turbo_headers(from_post_page)
    assert_sent_to_verify

    delete post_bookmark_path(@post), headers: turbo_headers(from_post_page)
    assert_sent_to_verify
  end

  test "writing a comment or a reply is refused and nothing is saved" do
    assert_no_difference "Comment.count" do
      post post_comments_path(@post), params: { comment: { body: "Hello" } }, headers: turbo_headers(from_post_page)
      assert_sent_to_verify

      post comment_replies_path(@comment), params: { comment: { body: "Hello" } }, headers: turbo_headers(from_post_page)
      assert_sent_to_verify
    end
  end

  test "liking a comment is refused" do
    assert_no_difference "Like.count" do
      post comment_like_path(@comment), headers: turbo_headers(from_post_page)
      assert_sent_to_verify

      delete comment_like_path(@comment), headers: turbo_headers(from_post_page)
      assert_sent_to_verify
    end
  end

  test "the page of the press is remembered, and verifying returns there" do
    post post_like_path(@post), headers: turbo_headers(from_post_page)
    assert_equal post_page_path_for(@post), session[:return_to_after_authenticating]

    _, code = EmailVerificationCode.issue(@person)
    post email_verification_path, params: { otp: code }

    assert_redirected_to post_page_path_for(@post)
  end

  test "a referer from another site is never used as the page to return to" do
    post post_like_path(@post), headers: { "Referer" => "http://evil.example.com/phish" }

    assert_nil session[:return_to_after_authenticating]
  end

  test "after verifying, the same press works" do
    @person.verify_email!

    assert_difference "Like.count", 1 do
      post post_like_path(@post), headers: turbo_headers
    end
    assert_response :success
  end

  # What is still allowed

  test "reading and sharing are open to someone who has not verified" do
    get post_page_path_for(@post)
    assert_response :success

    get post_comments_path(@post), headers: frame_headers("comments_panel")
    assert_response :success

    get comment_replies_path(@comment), headers: frame_headers(dom_id(@comment, :replies))
    assert_response :success

    assert_difference -> { @post.reload.shares_count }, 1 do
      post post_share_path(@post), headers: turbo_headers
    end
    assert_response :success
  end

  test "the profile, the account page and the saved list are open too" do
    get profile_path(@person.username)
    assert_response :success

    get edit_account_path
    assert_response :success

    get saved_posts_path
    assert_response :success
  end

  # The comments window sends the user out of the window

  test "the writing boxes and the heart leave the window and say why" do
    get post_comments_path(@post), headers: frame_headers("comments_panel")

    assert_select "#comment_form form[data-turbo-frame='_top']"
    assert_select "#comment_form p", "You will be asked to verify your email"
    assert_select "##{dom_id(@comment, :like)} form[data-turbo-frame='_top']"
    assert_select "details##{dom_id(@comment, :reply_form)} form[data-turbo-frame='_top']"
  end

  test "for a verified user they stay in the window" do
    sign_in_as(@author)

    get post_comments_path(@post), headers: frame_headers("comments_panel")

    assert_select "#comment_form form:not([data-turbo-frame])"
    assert_select "#comment_form p", "Up to 1000 characters"
    assert_select "##{dom_id(@comment, :like)} form:not([data-turbo-frame])"
    assert_select "details##{dom_id(@comment, :reply_form)} form:not([data-turbo-frame])"
  end
end

class VerifyEmailNoticeTest < ActionDispatch::IntegrationTest
  include PostBuilder

  test "an unverified user sees the notice on ordinary pages, with a link to verify" do
    sign_in_as(create_unverified_user("notice_user"))

    [ root_path, about_path, edit_account_path, post_page_path_for(create_post) ].each do |path|
      get path

      assert_select "div.alert-warning[role=status]", text: /not verified yet/
      assert_select "div.alert-warning a[href=?]", email_verification_path, text: "Verify now"
    end
  end

  test "the verification page does not repeat the notice" do
    sign_in_as(create_unverified_user("notice_user"))

    get email_verification_path

    assert_select "div.alert-warning", 0
  end

  test "a verified user does not see it" do
    sign_in_as(users(:one))

    get root_path

    assert_select "div.alert-warning", 0
  end

  test "a visitor who is not signed in does not see it" do
    get root_path

    assert_select "div.alert-warning", 0
  end
end
