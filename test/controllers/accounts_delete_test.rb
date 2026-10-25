require "test_helper"
require_relative "../support/post_builder"

class AccountsDeleteTest < ActionDispatch::IntegrationTest
  include PostBuilder

  setup do
    @user = users(:one)
    @other = users(:two)
    @post = create_post
  end

  def delete_account(username = @user.username)
    delete account_path, params: { confirm_username: username }
  end

  test "a signed out visitor cannot delete an account" do
    assert_no_difference "User.count" do
      delete_account
    end

    assert_redirected_to new_session_path
  end

  test "the right username deletes the account, its sessions and its comments" do
    sign_in_as(@user)
    Comment.create!(user: @user, post: @post, body: "My comment")

    assert_difference "User.count", -1 do
      delete_account
    end

    assert_redirected_to root_path
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_not Session.exists?(user_id: @user.id)
    assert_not Comment.exists?(user_id: @user.id)
  end

  test "the username is accepted in any letter case and with spaces around it" do
    sign_in_as(@user)

    assert_difference "User.count", -1 do
      delete_account("  #{@user.username.upcase}  ")
    end
  end

  test "a wrong username deletes nothing" do
    sign_in_as(@user)

    assert_no_difference [ "User.count", "Session.count" ] do
      delete_account("someone_else")
    end

    assert_redirected_to edit_account_path(anchor: "delete")
    assert_equal "The username you typed does not match.", flash[:alert]
  end

  test "a missing username deletes nothing" do
    sign_in_as(@user)

    assert_no_difference "User.count" do
      delete account_path
    end

    assert_redirected_to edit_account_path(anchor: "delete")
  end

  test "an admin account cannot be deleted here" do
    sign_in_as(@other)
    @other.update_column(:admin, true)

    assert_no_difference "User.count" do
      delete_account(@other.username)
    end

    assert_redirected_to edit_account_path(anchor: "delete")
  end

  test "a user's own reply under their own comment keeps the post counter correct" do
    sign_in_as(@user)
    parent = Comment.create!(user: @user, post: @post, body: "Top level")
    Comment.create!(user: @user, post: @post, parent: parent, body: "My own reply")
    Comment.create!(user: @other, post: @post, parent: parent, body: "Reply from someone else")
    survivor = Comment.create!(user: @other, post: @post, body: "Not mine")

    assert_equal 4, @post.reload.comments_count

    delete_account

    assert_response :see_other
    assert Comment.exists?(survivor.id)
    assert_equal 1, Comment.where(post_id: @post.id).count
    assert_equal 1, @post.reload.comments_count
  end

  test "deleting a user removes their likes and saves and lowers the counters" do
    sign_in_as(@user)
    comment = Comment.create!(user: @other, post: @post, body: "Someone else's comment")
    Like.create!(user: @user, likeable: comment)
    Bookmark.create!(user: @user, post: @post)

    assert_equal 1, comment.reload.likes_count
    assert_equal 1, @post.reload.bookmarks_count

    delete_account

    assert_equal 0, comment.reload.likes_count
    assert_equal 0, @post.reload.bookmarks_count
  end
end
