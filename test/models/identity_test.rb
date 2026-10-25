require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  test "a known service with an id is valid" do
    assert @user.identities.build(provider: "github", uid: "1").valid?
    assert @user.identities.build(provider: "google_oauth2", uid: "1").valid?
  end

  test "the service must be one that is supported" do
    identity = @user.identities.build(provider: "facebook", uid: "1")

    assert_not identity.valid?
    assert_includes identity.errors[:provider], "is not included in the list"
  end

  test "the id from the service is required" do
    identity = @user.identities.build(provider: "github", uid: "")

    assert_not identity.valid?
    assert_includes identity.errors[:uid], "can't be blank"
  end

  test "the names shown to people" do
    assert_equal "GitHub", Identity.new(provider: "github").provider_name
    assert_equal "Google", Identity.new(provider: "google_oauth2").provider_name
  end

  test "one account of a service cannot belong to two users" do
    @user.identities.create!(provider: "github", uid: "1")
    second = @other.identities.build(provider: "github", uid: "1")

    assert_not second.valid?
    assert_includes second.errors[:uid], "has already been taken"
  end

  test "two services may use the same id" do
    @user.identities.create!(provider: "github", uid: "1")

    assert @other.identities.build(provider: "google_oauth2", uid: "1").valid?
  end

  test "a user cannot connect the same service twice" do
    @user.identities.create!(provider: "github", uid: "1")
    second = @user.identities.build(provider: "github", uid: "2")

    assert_not second.valid?
    assert_includes second.errors[:provider], "has already been taken"
  end

  test "the database also refuses duplicates" do
    @user.identities.create!(provider: "github", uid: "1")

    assert_raises(ActiveRecord::RecordNotUnique) do
      @other.identities.build(provider: "github", uid: "1").save(validate: false)
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      @user.identities.build(provider: "github", uid: "2").save(validate: false)
    end
  end
end
