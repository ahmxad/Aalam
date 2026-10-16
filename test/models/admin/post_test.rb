require "test_helper"

class Admin::PostTest < ActiveSupport::TestCase
  def build_post(title:, card:)
    Admin::Post.new(title: title, summary: "A summary", body: "A body", card: card)
  end

  test "rejects the same title twice inside one card" do
    existing = admin_posts(:one)
    post = build_post(title: existing.title, card: existing.card)

    assert_not post.valid?
    assert post.errors[:title].any?
  end

  test "rejects a different title that produces the same slug in one card" do
    existing = admin_posts(:one)
    post = build_post(title: "#{existing.title}!", card: existing.card)

    assert_not post.valid?
    assert_includes post.errors[:slug], "is already taken in this card"
  end

  test "allows the same title in a different card" do
    existing = admin_posts(:one)
    post = build_post(title: existing.title, card: admin_cards(:two))

    assert post.valid?
  end

  test "requires a title, summary and body" do
    post = Admin::Post.new(card: admin_cards(:one))

    assert_not post.valid?
    assert post.errors[:title].any?
    assert post.errors[:summary].any?
    assert post.errors[:body].any?
  end
end
