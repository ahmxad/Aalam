require "test_helper"
require_relative "../support/post_builder"

class EngagementCleanupTest < ActiveSupport::TestCase
  include PostBuilder

  setup do
    @post = create_post
    @user = users(:one)
    @other = users(:two)
  end

  test "deleting a post deletes its likes, saves, comments, replies and their likes" do
    comment = Comment.create!(user: @user, post: @post, body: "Top")
    reply = Comment.create!(user: @other, post: @post, parent: comment, body: "Reply")
    Like.create!(user: @user, likeable: @post)
    Like.create!(user: @user, likeable: comment)
    Like.create!(user: @user, likeable: reply)
    Bookmark.create!(user: @user, post: @post)

    assert_difference "Like.count", -3 do
      assert_difference "Comment.count", -2 do
        assert_difference "Bookmark.count", -1 do
          @post.destroy
        end
      end
    end
  end

  test "deleting a user deletes what they liked, saved and wrote, and fixes the counts" do
    person = User.create!(username: "leaving_user", email_address: "leaving@example.com", password: "password123")
    comment = Comment.create!(user: @user, post: @post, body: "Not theirs")
    Like.create!(user: person, likeable: @post)
    Like.create!(user: person, likeable: comment)
    Bookmark.create!(user: person, post: @post)
    Comment.create!(user: person, post: @post, body: "Theirs")

    person.destroy

    assert_equal 0, Like.where(user_id: person.id).count
    assert_equal 0, Bookmark.where(user_id: person.id).count
    assert_equal 0, Comment.where(user_id: person.id).count

    assert_equal 0, @post.reload.likes_count
    assert_equal 0, @post.bookmarks_count
    assert_equal 1, @post.comments_count
    assert_equal 0, comment.reload.likes_count
  end

  test "deleting a whole topic takes the engagement of its posts with it" do
    Like.create!(user: @user, likeable: @post)
    Comment.create!(user: @user, post: @post, body: "Gone soon")

    assert_difference [ "Like.count", "Comment.count" ], -1 do
      @post.card.topic.destroy
    end
  end
end
