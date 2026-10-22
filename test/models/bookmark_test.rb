require "test_helper"
require_relative "../support/post_builder"

class BookmarkTest < ActiveSupport::TestCase
  include PostBuilder

  setup do
    @post = create_post
    @user = users(:one)
    @other = users(:two)
  end

  test "saving a post raises its save count and removing it lowers it" do
    bookmark = Bookmark.create!(user: @user, post: @post)
    assert_equal 1, @post.reload.bookmarks_count

    bookmark.destroy
    assert_equal 0, @post.reload.bookmarks_count
  end

  test "different people can save the same post" do
    Bookmark.create!(user: @user, post: @post)
    Bookmark.create!(user: @other, post: @post)

    assert_equal 2, @post.reload.bookmarks_count
  end

  test "one person cannot save the same post twice" do
    Bookmark.create!(user: @user, post: @post)
    duplicate = Bookmark.new(user: @user, post: @post)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:post_id], "has already been taken"
  end

  test "the database also refuses a second save from the same person" do
    Bookmark.create!(user: @user, post: @post)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Bookmark.new(user: @user, post: @post).save(validate: false)
    end
  end

  test "a person can save many different posts" do
    other_post = create_post(card: @post.card)

    assert Bookmark.new(user: @user, post: @post).save
    assert Bookmark.new(user: @user, post: other_post).save
  end
end
