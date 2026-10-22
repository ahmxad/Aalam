class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :redirect_if_authenticated
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      announce_verification_code(@user)
      redirect_to email_verification_path
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # admin is deliberately not permitted, so nobody can promote themselves
    def registration_params
      params.expect(user: [ :username, :email_address, :password, :password_confirmation, :avatar_upload ])
    end

    def redirect_if_authenticated
      redirect_to root_path if authenticated?
    end

    # The new account must prove its email address before it can like, save or comment.
    # The page the person came from stays remembered, and they return there after verifying.
    def announce_verification_code(user)
      if EmailVerificationCode.deliver_to(user) == :sent
        flash[:notice] = "Welcome to Aalam! We sent a 6 digit code to #{helpers.masked_email(user.email_address)}."
      else
        flash[:alert] = "Your account is ready, but we could not send the code. Press \"Send me a code\" to try again."
      end
    end
end
