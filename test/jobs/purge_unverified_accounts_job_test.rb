require "test_helper"
require "minitest/mock"

class PurgeUnverifiedAccountsJobTest < ActiveSupport::TestCase
  # An account that was made `age` ago and has never proved its email address
  def create_unverified(username, age: 2.days, **attributes)
    user = User.create!({ username: username, email_address: "#{username}@example.com", password: "password123" }.merge(attributes))
    user.update_columns(created_at: age.ago)
    user
  end

  test "an account unverified for over a day is deleted and counted" do
    stale = create_unverified("stale_one", age: 25.hours)

    assert_equal 1, PurgeUnverifiedAccountsJob.perform_now
    assert_not User.exists?(stale.id)
  end

  test "an account younger than a day is kept" do
    young = create_unverified("young_one", age: 23.hours)

    assert_equal 0, PurgeUnverifiedAccountsJob.perform_now
    assert User.exists?(young.id)
  end

  test "a verified account is kept however old it is" do
    old = create_unverified("old_verified", age: 30.days)
    old.update_columns(email_verified_at: 29.days.ago)

    assert_equal 0, PurgeUnverifiedAccountsJob.perform_now
    assert User.exists?(old.id)
  end

  test "an admin is never deleted" do
    admin = create_unverified("old_admin", age: 30.days, admin: true)

    assert_equal 0, PurgeUnverifiedAccountsJob.perform_now
    assert User.exists?(admin.id)
  end

  test "only the stale accounts are listed" do
    stale = create_unverified("stale_two")
    create_unverified("young_two", age: 1.hour)

    assert_equal [ stale ], PurgeUnverifiedAccountsJob.stale_users.to_a
  end

  test "the connected services and codes of a deleted account go with it" do
    stale = create_unverified("stale_three")
    stale.identities.create!(provider: "github", uid: "555")
    EmailVerificationCode.issue(stale)

    assert_difference [ "Identity.count", "EmailVerificationCode.count" ], -1 do
      PurgeUnverifiedAccountsJob.perform_now
    end
  end

  test "an account that was verified after the list was made is kept" do
    user = create_unverified("just_verified")
    listed = User.find(user.id)
    User.where(id: user.id).update_all(email_verified_at: Time.current)

    fake_list = Object.new
    fake_list.define_singleton_method(:find_each) { |&block| [ listed ].each(&block) }

    PurgeUnverifiedAccountsJob.stub(:stale_users, fake_list) do
      assert_equal 0, PurgeUnverifiedAccountsJob.perform_now
    end

    assert User.exists?(user.id)
  end

  test "codes older than two days are removed and newer ones stay" do
    old_code = EmailVerificationCode.create!(user: users(:one), email: "one@example.com", code_digest: "a" * 64,
                                             expires_at: 3.days.ago, created_at: 3.days.ago)
    recent_code = EmailVerificationCode.create!(user: users(:one), email: "one@example.com", code_digest: "b" * 64,
                                                expires_at: 1.day.ago, created_at: 1.day.ago)

    PurgeUnverifiedAccountsJob.perform_now

    assert_not EmailVerificationCode.exists?(old_code.id)
    assert EmailVerificationCode.exists?(recent_code.id)
  end

  test "the job is scheduled every day in production" do
    path = Rails.root.join("config/recurring.yml")
    config = YAML.safe_load(ERB.new(path.read).result, aliases: true)
    task = config.fetch("production").values.find { |entry| entry["class"] == "PurgeUnverifiedAccountsJob" }

    assert task, "PurgeUnverifiedAccountsJob is missing from config/recurring.yml"
    assert_equal "every day at 3am", task["schedule"]
  end
end
