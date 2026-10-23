class EmailVerificationsController < ApplicationController
  before_action :set_user
  before_action :load_code
  before_action :redirect_if_nothing_to_confirm

  # Together with the limits on the code itself, this keeps guessing hopeless
  rate_limit to: 30, within: 10.minutes, only: %i[create resend], name: "verify",
             by: -> { Current.session.user_id },
             with: -> { redirect_to email_verification_path, alert: "Too many attempts. Please wait a few minutes." }

  def show
  end

  def create
    result = @code ? @code.check(params[:otp].to_s.gsub(/\D/, "")) : :expired

    case result
    when :ok
      finish_verification
    when :wrong
      render_problem "That code is not right. You have #{@code.attempts_left} tries left."
    when :locked
      render_problem "Too many wrong tries. Ask for a new code."
    else
      render_problem "That code has expired. Ask for a new code."
    end
  end

  def resend
    # A code for a new address goes to that address again, not to the one the account uses now
    email = @code&.email || @user.email_address

    if EmailVerificationCode.deliver_to(@user, email: email) == :sent
      redirect_to email_verification_path, notice: "We sent a new code to #{helpers.masked_email(email)}."
    else
      redirect_to email_verification_path, alert: "We could not send the email. Please try again in a minute."
    end
  rescue EmailVerificationCode::Throttled => error
    redirect_to email_verification_path,
                alert: "Please wait #{helpers.distance_of_time_in_words(error.retry_in)} before asking for another code."
  end

  # Cancels a change of email address that is waiting for its code
  def destroy
    if @code && @code.email != @user.email_address
      EmailVerificationCode.where(user_id: @user.id, consumed_at: nil).update_all(consumed_at: Time.current)
      redirect_to edit_account_path(anchor: "email"), status: :see_other, notice: "The email change was cancelled."
    else
      redirect_to email_verification_path, status: :see_other
    end
  end

  private
    # Works on its own copy of the signed in user, like the account page does
    def set_user
      @user = User.find(Current.session.user_id)
    end

    def load_code
      @code = EmailVerificationCode.current_for(@user)
    end

    # Someone with a verified address and no change waiting has nothing to do here
    def redirect_if_nothing_to_confirm
      redirect_to root_path, notice: "Your email is already verified." if @user.email_verified? && @code.nil?
    end

    def finish_verification
      if @code.email == @user.email_address
        @user.verify_email!
        redirect_to after_authentication_url, notice: "Your email is verified. Welcome aboard!"
      else
        apply_email_change
      end
    end

    # The code was sent to a new address and is right, so the address is proved and now the account's
    def apply_email_change
      old_email = @user.email_address

      if @user.update(email_address: @code.email, email_verified_at: Time.current)
        # The email address is the key to the account, so every other device has to sign in again
        @user.sessions.where.not(id: Current.session.id).destroy_all
        EmailChangeMailer.notice(@user, old_email).deliver_later
        redirect_to edit_account_path(anchor: "email"), notice: "Your email address is now #{@user.email_address}."
      else
        problem = @user.errors.full_messages.to_sentence
        @user.reload
        render_problem "#{problem}. Please start the change again."
      end
    end

    def render_problem(message)
      @code = EmailVerificationCode.current_for(@user)

      if @code.nil? && @user.email_verified?
        redirect_to edit_account_path(anchor: "email"), alert: "That did not work out. Please start the email change again."
      else
        flash.now[:alert] = message
        render :show, status: :unprocessable_content
      end
    end
end
