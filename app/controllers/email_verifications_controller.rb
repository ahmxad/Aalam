class EmailVerificationsController < ApplicationController
  before_action :set_user
  before_action :redirect_if_verified

  # Together with the limits on the code itself, this keeps guessing hopeless
  rate_limit to: 30, within: 10.minutes, only: %i[create resend], name: "verify",
             by: -> { Current.session.user_id },
             with: -> { redirect_to email_verification_path, alert: "Too many attempts. Please wait a few minutes." }

  def show
    @code = EmailVerificationCode.current_for(@user)
  end

  def create
    @code = EmailVerificationCode.current_for(@user)
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
    if EmailVerificationCode.deliver_to(@user) == :sent
      redirect_to email_verification_path, notice: "We sent a new code to #{helpers.masked_email(@user.email_address)}."
    else
      redirect_to email_verification_path, alert: "We could not send the email. Please try again in a minute."
    end
  rescue EmailVerificationCode::Throttled => error
    redirect_to email_verification_path,
                alert: "Please wait #{helpers.distance_of_time_in_words(error.retry_in)} before asking for another code."
  end

  private
    # Works on its own copy of the signed in user, like the account page does
    def set_user
      @user = User.find(Current.session.user_id)
    end

    def redirect_if_verified
      redirect_to root_path, notice: "Your email is already verified." if @user.email_verified?
    end

    def finish_verification
      if @code.email == @user.email_address
        @user.verify_email!
        redirect_to after_authentication_url, notice: "Your email is verified. Welcome aboard!"
      else
        # The code was sent to an address the account no longer uses
        render_problem "That code was for a different email address. Ask for a new code."
      end
    end

    def render_problem(message)
      @code = EmailVerificationCode.current_for(@user)
      flash.now[:alert] = message
      render :show, status: :unprocessable_content
    end
end
