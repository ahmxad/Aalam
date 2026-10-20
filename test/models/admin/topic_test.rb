require "test_helper"

class Admin::TopicTest < ActiveSupport::TestCase
  test "is valid with a title and an image" do
    assert Admin::Topic.new(title: "Brand New Topic", image: sample_image).valid?
  end

  test "requires a title" do
    topic = Admin::Topic.new(title: "", image: sample_image)

    assert_not topic.valid?
    assert_includes topic.errors[:title], "can't be blank"
  end

  test "requires an image on create" do
    topic = Admin::Topic.new(title: "No Image Topic")

    assert_not topic.valid?
    assert_includes topic.errors[:image], "must be attached"
  end

  test "generates the slug from the title" do
    topic = Admin::Topic.new(title: "Hello, World!", image: sample_image)
    topic.valid?

    assert_equal "hello-world", topic.slug
  end

  test "rejects a title with no Latin letters or digits" do
    topic = Admin::Topic.new(title: "عالم", image: sample_image)

    assert_not topic.valid?
    assert_includes topic.errors[:slug], "could not be generated: include at least one Latin letter or digit in the title"
  end

  test "accepts a title that mixes non-Latin text with Latin letters" do
    topic = Admin::Topic.new(title: "Aalam عالم", image: sample_image)

    assert topic.valid?
    assert_equal "aalam", topic.slug
  end

  test "shows only the slug generation error when a broken record already has an empty slug" do
    Admin::Topic.new(title: "Legacy", slug: "", image: sample_image).save!(validate: false)

    topic = Admin::Topic.new(title: "عالم", image: sample_image)

    assert_not topic.valid?
    assert_equal [ "could not be generated: include at least one Latin letter or digit in the title" ], topic.errors[:slug]
  end

  test "rejects a duplicate title, ignoring case" do
    Admin::Topic.create!(title: "Unique Name", image: sample_image)
    duplicate = Admin::Topic.new(title: "unique name", image: sample_image)

    assert_not duplicate.valid?
    assert duplicate.errors[:slug].any?
  end

  test "rejects a file that is not an image" do
    topic = Admin::Topic.new(title: "Text File Topic")
    topic.image.attach(io: StringIO.new("hello"), filename: "a.txt", content_type: "text/plain")

    assert_not topic.valid?
    assert_includes topic.errors[:image], "must be a JPEG, PNG or WebP"
  end

  test "rejects an image larger than 5 MB" do
    png = File.binread(Rails.root.join("test/fixtures/files/test.png"))
    topic = Admin::Topic.new(title: "Big Image Topic")
    topic.image.attach(io: StringIO.new(png + ("\0" * 6.megabytes)), filename: "big.png", content_type: "image/png")

    assert_not topic.valid?
    assert_includes topic.errors[:image], "must be smaller than 5 MB"
  end

  test "destroying a topic also destroys its cards and posts" do
    topic = admin_topics(:one)

    assert_difference({ "Admin::Card.count" => -2, "Admin::Post.count" => -2 }) do
      topic.destroy!
    end
  end
end
