require "test_helper"
require_relative "../support/image_fixtures"

class WebpConvertibleTest < ActiveSupport::TestCase
  include ImageFixtures

  test "a topic image uploaded as JPEG is stored as WebP" do
    topic = Admin::Topic.new(title: "Converted topic", image: uploaded_image(:jpeg, filename: "cover.jpg"))

    assert topic.save, topic.errors.full_messages.to_sentence
    assert_equal "image/webp", topic.image.content_type
    assert_equal "cover.webp", topic.image.filename.to_s
  end

  test "a card image uploaded as PNG is stored as WebP" do
    topic = Admin::Topic.create!(title: "Parent topic", image: uploaded_image(:webp))
    card = Admin::Card.new(topic: topic, title: "Converted card", image: uploaded_image(:png, filename: "diagram.png"))

    assert card.save, card.errors.full_messages.to_sentence
    assert_equal "image/webp", card.image.content_type
    assert_equal "diagram.webp", card.image.filename.to_s
  end

  test "an image that is too big is still rejected by the normal validation" do
    big = uploaded_file("a" * 6.megabytes, filename: "huge.jpg", content_type: "image/jpeg")
    topic = Admin::Topic.new(title: "Too big", image: big)

    assert_not topic.valid?
    assert_includes topic.errors[:image], "must be smaller than 5 MB"
  end

  test "a topic still needs an image" do
    topic = Admin::Topic.new(title: "No image")

    assert_not topic.valid?
    assert_includes topic.errors[:image], "must be attached"
  end
end
