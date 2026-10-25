require "test_helper"
require_relative "../support/post_builder"

class LikeTest < ActiveSupport::TestCase
  include PostBuilder

  setup do
    @post = create_post
    @user = users(:one)
    @other = users(:two)
  end

  test "liking a post raises its like count and unliking lowers it" do
    like = Like.create!(user: @user, likeable: @post)
    assert_equal 1, @post.reload.likes_count

    like.destroy
    assert_equal 0, @post.reload.likes_count
  end

  test "different people can like the same post" do
    Like.create!(user: @user, likeable: @post)
    Like.create!(user: @other, likeable: @post)

    assert_equal 2, @post.reload.likes_count
  end

  test "one person cannot like the same post twice" do
    Like.create!(user: @user, likeable: @post)
    duplicate = Like.new(user: @user, likeable: @post)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:likeable_id], "has already been taken"
  end

  test "the database also refuses a second like from the same person" do
    Like.create!(user: @user, likeable: @post)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Like.new(user: @user, likeable: @post).save(validate: false)
    end
  end

  test "a comment can be liked too, and its count is separate from the post" do
    comment = Comment.create!(user: @user, post: @post, body: "Nice post")
    Like.create!(user: @other, likeable: comment)

    assert_equal 1, comment.reload.likes_count
    assert_equal 0, @post.reload.likes_count
  end

  test "a person can like a post and a comment on it" do
    comment = Comment.create!(user: @user, post: @post, body: "Nice post")

    assert Like.new(user: @user, likeable: @post).save
    assert Like.new(user: @user, likeable: comment).save
  end
end
