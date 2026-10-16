require "test_helper"

class Admin::CardTest < ActiveSupport::TestCase
  test "rejects the same title twice inside one topic" do
    existing = admin_cards(:one)
    card = Admin::Card.new(title: existing.title, topic: existing.topic, image: sample_image)

    assert_not card.valid?
    assert_includes card.errors[:slug], "is already taken in this topic"
  end

  test "allows the same title in a different topic" do
    existing = admin_cards(:one)
    other_topic = Admin::Topic.create!(title: "Another Topic", image: sample_image)
    card = Admin::Card.new(title: existing.title, topic: other_topic, image: sample_image)

    assert card.valid?
  end

  test "requires a title" do
    card = Admin::Card.new(title: "", topic: admin_topics(:one), image: sample_image)

    assert_not card.valid?
    assert_includes card.errors[:title], "can't be blank"
  end

  test "requires an image on create" do
    card = Admin::Card.new(title: "No Image Card", topic: admin_topics(:one))

    assert_not card.valid?
    assert_includes card.errors[:image], "must be attached"
  end

  test "destroying a card also destroys its posts" do
    card = admin_cards(:one)

    assert_difference("Admin::Post.count", -1) do
      card.destroy!
    end
  end
end
