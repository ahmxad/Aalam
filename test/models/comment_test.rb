require "test_helper"
require_relative "../support/post_builder"

class CommentTest < ActiveSupport::TestCase
  include PostBuilder

  setup do
    @post = create_post
    @author = users(:one)
    @other = users(:two)
  end

  def add_comment(body = "A comment", user: @author)
    Comment.create!(user: user, post: @post, body: body)
  end

  def add_reply(parent, body = "A reply", user: @author)
    Comment.create!(user: user, post: @post, parent: parent, body: body)
  end

  # Every comment of the post in the given order, loaded a few at a time like the comments window does
  def page_through(sort, per_page:)
    seen = []
    cursor = nil

    loop do
      page = @post.comments.top_level.sorted_page(sort: sort, cursor: cursor, limit: per_page).to_a
      break if page.empty?

      seen.concat(page)
      cursor = page.last.cursor_for(sort)
    end

    seen
  end

  # Text

  test "a comment needs text" do
    comment = Comment.new(user: @author, post: @post, body: "   ")

    assert_not comment.valid?
    assert_includes comment.errors[:body], "can't be blank"
  end

  test "the text is trimmed and its line breaks are made uniform" do
    comment = add_comment("  Hello\r\nthere\rfriend  ")

    assert_equal "Hello\nthere\nfriend", comment.body
  end

  test "the text is limited to 1000 characters" do
    assert Comment.new(user: @author, post: @post, body: "a" * 1000).valid?

    too_long = Comment.new(user: @author, post: @post, body: "a" * 1001)
    assert_not too_long.valid?
    assert_includes too_long.errors[:body], "is too long (maximum is 1000 characters)"
  end

  # Counters and replies

  test "a comment raises the comment count of its post" do
    add_comment

    assert_equal 1, @post.reload.comments_count
  end

  test "a reply counts as a comment of the post and as a reply of its parent" do
    parent = add_comment
    add_reply(parent)

    assert_equal 2, @post.reload.comments_count
    assert_equal 1, parent.reload.replies_count
  end

  test "a reply is known as a reply and a comment is not" do
    parent = add_comment
    reply = add_reply(parent)

    assert reply.reply?
    assert_not parent.reply?
    assert_equal [ parent ], @post.comments.top_level.to_a
  end

  test "a reply to a reply is not allowed" do
    reply = add_reply(add_comment)
    nested = Comment.new(user: @author, post: @post, parent: reply, body: "Even deeper")

    assert_not nested.valid?
    assert_includes nested.errors[:parent], "can't be a reply"
  end

  test "a reply must be on the same post as its parent" do
    parent = add_comment
    reply = Comment.new(user: @author, post: create_post, parent: parent, body: "Wrong post")

    assert_not reply.valid?
    assert_includes reply.errors[:parent], "must be a comment on the same post"
  end

  test "deleting a comment deletes its replies and their likes and fixes the counts" do
    parent = add_comment
    reply = add_reply(parent)
    Like.create!(user: @other, likeable: parent)
    Like.create!(user: @other, likeable: reply)

    assert_difference [ "Comment.count", "Like.count" ], -2 do
      parent.destroy
    end

    assert_equal 0, @post.reload.comments_count
  end

  test "deleting a reply lowers the reply count of its parent and the comment count of the post" do
    parent = add_comment
    reply = add_reply(parent)

    reply.destroy

    assert_equal 0, parent.reload.replies_count
    assert_equal 1, @post.reload.comments_count
  end

  # Who can delete

  test "the author and admins can delete a comment, other people cannot" do
    comment = add_comment

    assert comment.deletable_by?(@author)
    assert comment.deletable_by?(@other), "users(:two) is an admin"

    stranger = User.create!(username: "stranger", email_address: "stranger@example.com", password: "password123")
    assert_not comment.deletable_by?(stranger)
    assert_not comment.deletable_by?(nil)
  end

  # Sorting and pages

  test "latest sorting pages through every comment exactly once" do
    created = Array.new(7) { |index| add_comment("Comment #{index}") }

    assert_equal created.reverse.map(&:id), page_through("latest", per_page: 3).map(&:id)
  end

  test "sorting by replies puts the most replied comment first and pages without repeats" do
    comments = Array.new(5) { |index| add_comment("Comment #{index}") }
    [ 0, 3, 1, 3, 0 ].each_with_index { |count, index| count.times { add_reply(comments[index]) } }

    expected = comments.map(&:reload).sort_by { |comment| [ -comment.replies_count, -comment.id ] }

    assert_equal expected.map(&:id), page_through("replies", per_page: 2).map(&:id)
    assert_equal comments[3].id, page_through("replies", per_page: 2).first.id, "ties go to the newer comment"
  end

  test "sorting by likes puts the most liked comment first and pages without repeats" do
    people = [ @author, @other ]
    comments = Array.new(5) { |index| add_comment("Comment #{index}") }
    [ 0, 2, 1, 2, 0 ].each_with_index do |count, index|
      count.times { |number| Like.create!(user: people[number], likeable: comments[index]) }
    end

    expected = comments.map(&:reload).sort_by { |comment| [ -comment.likes_count, -comment.id ] }

    assert_equal expected.map(&:id), page_through("likes", per_page: 2).map(&:id)
  end

  test "a new comment arriving between two pages does not repeat or skip anything" do
    created = Array.new(4) { |index| add_comment("Comment #{index}") }
    first = @post.comments.top_level.sorted_page(sort: "latest", limit: 2).to_a

    add_comment("Arrived meanwhile")
    second = @post.comments.top_level.sorted_page(sort: "latest", cursor: first.last.cursor_for("latest"), limit: 2).to_a

    assert_equal created.reverse.map(&:id), (first + second).map(&:id)
  end

  test "the cursor of a comment depends on the sorting" do
    comment = add_comment
    add_reply(comment)
    Like.create!(user: @other, likeable: comment)
    comment.reload

    assert_equal comment.id.to_s, comment.cursor_for("latest")
    assert_equal "1-#{comment.id}", comment.cursor_for("replies")
    assert_equal "1-#{comment.id}", comment.cursor_for("likes")
  end

  test "a cursor in the wrong shape is ignored" do
    add_comment
    top_level = @post.comments.top_level

    [ "abc", "1-2", "", nil, "1; DROP TABLE comments" ].each do |cursor|
      assert_equal 1, top_level.sorted_page(sort: "latest", cursor: cursor).to_a.size, "cursor #{cursor.inspect}"
    end
    assert_equal 1, top_level.sorted_page(sort: "replies", cursor: "5").to_a.size
  end
end
