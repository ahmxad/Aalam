# A one time code sent to an email address to prove that its owner can read that inbox.
# Only a keyed digest of the code is stored, never the code itself.
class EmailVerificationCode < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRES_IN = 10.minutes
  MAX_ATTEMPTS = 5
  RESEND_AFTER = 60.seconds
  MAX_PER_HOUR = 5

  # Raised when a new code is asked for too soon. retry_in is the number of seconds to wait.
  class Throttled < StandardError
    attr_reader :retry_in

    def initialize(retry_in)
      @retry_in = retry_in
      super("A new code was asked for too soon")
    end
  end

  belongs_to :user

  # Makes a new code and returns [record, code]. The code exists only here and in the email.
  # Any older code of the user stops working.
  def self.issue(user, email: user.email_address)
    user.with_lock do
      throttle!(user)

      code = generate_code
      where(user_id: user.id, consumed_at: nil).update_all(consumed_at: Time.current)
      record = create!(user: user, email: email, code_digest: digest(user.id, email, code),
                       expires_at: EXPIRES_IN.from_now)
      [ record, code ]
    end
  end

  # Makes a code and emails it to the address. Returns :sent, or :failed when the email could not be delivered.
  # Raises Throttled when a code was asked for too soon.
  def self.deliver_to(user, email: user.email_address)
    record, code = issue(user, email: email)

    begin
      EmailVerificationMailer.code(user, record.email, code).deliver_now
      :sent
    rescue StandardError => error
      Rails.logger.error("Verification email failed: #{error.class}: #{error.message}")
      # A code that never arrived must not look like it was sent, or hold back the next try
      record.destroy
      :failed
    end
  end

  # The code the user can still type in, if there is one
  def self.current_for(user)
    where(user_id: user.id, consumed_at: nil).where("expires_at > ?", Time.current).order(:created_at).last
  end

  def self.digest(user_id, email, code)
    OpenSSL::HMAC.hexdigest("SHA256", digest_key, "#{user_id}:#{email}:#{code}")
  end

  def self.generate_code
    format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
  end

  def self.digest_key
    Rails.application.key_generator.generate_key("email verification code")
  end

  # At most one code a minute and five an hour, so nobody can fill an inbox
  def self.throttle!(user)
    sent = where(user_id: user.id).where(created_at: 1.hour.ago..).order(:created_at).pluck(:created_at)
    return if sent.empty?

    since_last = Time.current - sent.last
    raise Throttled.new((RESEND_AFTER.to_i - since_last).ceil) if since_last < RESEND_AFTER
    raise Throttled.new((sent.first + 1.hour - Time.current).ceil) if sent.size >= MAX_PER_HOUR
  end
  private_class_method :throttle!

  # Checks a typed code. Returns :ok, :wrong, :expired or :locked.
  # The row is locked while it is checked, so guesses sent at the same moment are all counted.
  def check(code)
    with_lock do
      if consumed_at.present? || expires_at <= Time.current
        :expired
      elsif attempts >= MAX_ATTEMPTS
        :locked
      else
        increment!(:attempts)

        if ActiveSupport::SecurityUtils.secure_compare(self.class.digest(user_id, email, code.to_s.strip), code_digest)
          update!(consumed_at: Time.current)
          :ok
        elsif attempts >= MAX_ATTEMPTS
          :locked
        else
          :wrong
        end
      end
    end
  end

  def attempts_left
    [ MAX_ATTEMPTS - attempts, 0 ].max
  end
end
