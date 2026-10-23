# Removes accounts whose email address was never proved within a day, and old verification codes.
# Without this, anyone could keep a username or somebody else's email address reserved by signing up with it.
class PurgeUnverifiedAccountsJob < ApplicationJob
  queue_as :default

  # A person has this long to enter the code
  GRACE_PERIOD = 24.hours
  CODE_RETENTION = 2.days

  # The accounts this job would delete right now. Admins are never touched.
  def self.stale_users
    User.where(email_verified_at: nil, admin: false).where(created_at: ..GRACE_PERIOD.ago)
  end

  # Returns how many accounts were deleted
  def perform
    deleted = 0

    self.class.stale_users.find_each do |user|
      # The row is locked and read again, so an account that was verified a moment ago is kept
      user.with_lock do
        next if user.email_verified?

        user.destroy
        deleted += 1
      end
    end

    EmailVerificationCode.where(created_at: ..CODE_RETENTION.ago).delete_all

    deleted
  end
end
