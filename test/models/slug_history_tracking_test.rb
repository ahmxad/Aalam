require "test_helper"

class SlugHistoryTrackingTest < ActiveSupport::TestCase
  setup do
    @topic = Admin::Topic.create!(title: "Original Topic", image: sample_image)
  end

  test "records the old slug when the slug changes" do
    @topic.update!(title: "Renamed Topic")

    assert_equal [ "original-topic" ], @topic.slug_histories.pluck(:slug)
  end

  test "records nothing when the title changes but the slug stays the same" do
    @topic.update!(title: "Original Topic!")

    assert_equal "original-topic", @topic.slug
    assert_empty @topic.slug_histories
  end

  test "removes the history row for a slug the record uses again" do
    @topic.update!(title: "Renamed Topic")
    @topic.update!(title: "Original Topic")

    assert_equal [ "renamed-topic" ], @topic.slug_histories.pluck(:slug)
  end

  test "finds a record by its current slug without the old-slug flag" do
    record, outdated = Admin::Topic.find_by_slug_or_history(@topic.slug)

    assert_equal @topic, record
    assert_not outdated
  end

  test "finds a record by an old slug and flags it" do
    @topic.update!(title: "Renamed Topic")

    record, outdated = Admin::Topic.find_by_slug_or_history("original-topic")

    assert_equal @topic, record
    assert outdated
  end

  test "returns nothing for an unknown slug" do
    record, outdated = Admin::Topic.find_by_slug_or_history("never-existed")

    assert_nil record
    assert_not outdated
  end

  test "card history stays inside its own topic" do
    other_topic = Admin::Topic.create!(title: "Other Topic", image: sample_image)
    card = Admin::Card.create!(title: "Same Card", topic: @topic, image: sample_image)
    other_card = Admin::Card.create!(title: "Same Card", topic: other_topic, image: sample_image)
    card.update!(title: "Renamed Card")

    found, outdated = Admin::Card.find_by_slug_or_history("same-card", scope_id: @topic.id)
    assert_equal card, found
    assert outdated

    found, outdated = Admin::Card.find_by_slug_or_history("same-card", scope_id: other_topic.id)
    assert_equal other_card, found
    assert_not outdated
  end

  test "deleting a record deletes its history" do
    @topic.update!(title: "Renamed Topic")
    topic_id = @topic.id

    @topic.destroy!

    assert_not SlugHistory.exists?(sluggable_type: "Admin::Topic", sluggable_id: topic_id)
  end
end
