require "test_helper"
require "minitest/mock"

class EmailVerificationCodeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  def issue(user = @user, **options)
    EmailVerificationCode.issue(user, **options)
  end

  # Lets enough time pass to be allowed another code
  def wait_for_next_code
    travel EmailVerificationCode::RESEND_AFTER + 1.second
  end

  # A code that is certainly not the given one
  def wrong_code_for(code)
    (code.to_i + 1).to_s.rjust(6, "0")
  end

  # Making a code

  test "issue makes a six digit code and a record for the address" do
    record, code = issue

    assert_match(/\A\d{6}\z/, code)
    assert record.persisted?
    assert_equal @user, record.user
    assert_equal @user.email_address, record.email
    assert_nil record.consumed_at
    assert_equal 0, record.attempts
    assert_in_delta EmailVerificationCode::EXPIRES_IN.from_now.to_f, record.expires_at.to_f, 5
  end

  test "only a digest of the code is stored" do
    record, code = issue

    assert_match(/\A\h{64}\z/, record.code_digest)
    assert_not_includes record.attributes.values.map(&:to_s), code
    assert_equal EmailVerificationCode.digest(@user.id, record.email, code), record.code_digest
  end

  test "a code can be made for another address" do
    record, = issue(email: "new-address@example.com")

    assert_equal "new-address@example.com", record.email
  end

  test "the same code gives a different digest for another user or another address" do
    EmailVerificationCode.stub(:generate_code, "123456") do
      first, = issue
      second, = issue(@other)
      wait_for_next_code
      third, = issue(@other, email: "elsewhere@example.com")

      assert_equal 3, [ first, second, third ].map(&:code_digest).uniq.size
    end
  end

  # Finding the code to type in

  test "current_for returns the code the user can still type in" do
    assert_nil EmailVerificationCode.current_for(@user)

    record, = issue

    assert_equal record, EmailVerificationCode.current_for(@user)
    assert_nil EmailVerificationCode.current_for(@other)
  end

  test "current_for ignores a used code and an expired code" do
    record, code = issue
    record.check(code)
    assert_nil EmailVerificationCode.current_for(@user)

    wait_for_next_code
    issue
    travel EmailVerificationCode::EXPIRES_IN + 1.minute
    assert_nil EmailVerificationCode.current_for(@user)
  end

  test "a new code stops the older one from working" do
    old, old_code = issue
    wait_for_next_code
    fresh, fresh_code = issue

    assert_not_nil old.reload.consumed_at
    assert_equal :expired, old.check(old_code)
    assert_equal fresh, EmailVerificationCode.current_for(@user)
    assert_equal :ok, fresh.check(fresh_code)
  end

  # Checking a typed code

  test "the right code is accepted once" do
    record, code = issue

    assert_equal :ok, record.check(code)
    assert_not_nil record.reload.consumed_at
    assert_equal :expired, record.check(code)
  end

  test "the code may be typed with spaces around it" do
    record, code = issue

    assert_equal :ok, record.check("  #{code}\n")
  end

  test "a wrong code is refused and the tries are counted" do
    record, code = issue

    assert_equal :wrong, record.check(wrong_code_for(code))
    assert_equal 1, record.reload.attempts
    assert_equal 4, record.attempts_left
    assert_nil record.consumed_at
  end

  test "an empty or missing code is a wrong code" do
    record, = issue

    assert_equal :wrong, record.check("")
    assert_equal :wrong, record.check(nil)
  end

  test "five wrong tries lock the code, even for the right code afterwards" do
    record, code = issue
    wrong = wrong_code_for(code)

    4.times { assert_equal :wrong, record.check(wrong) }
    assert_equal :locked, record.check(wrong)
    assert_equal :locked, record.check(code)
    assert_nil record.reload.consumed_at
  end

  test "the right code still works on the last try" do
    record, code = issue
    4.times { record.check(wrong_code_for(code)) }

    assert_equal :ok, record.check(code)
  end

  test "a code works until it expires and not after" do
    record, code = issue
    travel 9.minutes
    assert_equal :ok, record.check(code)

    other_record, other_code = issue(@other)
    travel 11.minutes
    assert_equal :expired, other_record.check(other_code)
  end

  test "attempts_left never goes below zero" do
    record, = issue
    record.update_columns(attempts: 9)

    assert_equal 0, record.attempts_left
  end

  # Asking too often

  test "a second code asked for at once is refused with the time to wait" do
    issue

    error = assert_raises(EmailVerificationCode::Throttled) { issue }

    assert_includes 1..60, error.retry_in
    assert_equal 1, EmailVerificationCode.where(user: @user).count
  end

  test "after a minute another code is allowed" do
    issue
    wait_for_next_code

    assert_nothing_raised { issue }
  end

  test "five codes in an hour are the most" do
    5.times do
      issue
      wait_for_next_code
    end

    error = assert_raises(EmailVerificationCode::Throttled) { issue }
    assert_operator error.retry_in, :>, 3000
    assert_equal 5, EmailVerificationCode.where(user: @user).count

    travel 1.hour
    assert_nothing_raised { issue }
  end

  test "the limit is per user" do
    issue

    assert_nothing_raised { issue(@other) }
  end

  test "a used code still counts toward the limit" do
    record, code = issue
    record.check(code)

    assert_raises(EmailVerificationCode::Throttled) { issue }
  end

  # Emailing the code

  test "deliver_to emails a code that the record accepts" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      assert_equal :sent, EmailVerificationCode.deliver_to(@user)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_address ], mail.to

    code = mail.text_part.body.to_s[/\b\d{6}\b/]
    assert code, "the email should contain the code"
    assert_equal :ok, EmailVerificationCode.current_for(@user).check(code)
  end

  test "deliver_to can send the code to another address" do
    assert_equal :sent, EmailVerificationCode.deliver_to(@user, email: "new-address@example.com")

    assert_equal [ "new-address@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "new-address@example.com", EmailVerificationCode.current_for(@user).email
  end

  test "deliver_to reports a failure instead of raising when the email cannot be sent" do
    EmailVerificationMailer.stub(:code, ->(*) { raise "the mail server is down" }) do
      assert_equal :failed, EmailVerificationCode.deliver_to(@user)
    end
  end

  test "a code that could not be emailed is removed, so the next try is not held back" do
    EmailVerificationMailer.stub(:code, ->(*) { raise "the mail server is down" }) do
      EmailVerificationCode.deliver_to(@user)
    end

    assert_nil EmailVerificationCode.current_for(@user)
    assert_equal 0, EmailVerificationCode.where(user: @user).count
    assert_nothing_raised { EmailVerificationCode.deliver_to(@user) }
  end

  test "deliver_to passes on the limit on asking too often" do
    EmailVerificationCode.deliver_to(@user)

    assert_raises(EmailVerificationCode::Throttled) { EmailVerificationCode.deliver_to(@user) }
  end
end
