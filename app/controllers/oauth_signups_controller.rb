# The last step for someone who signs up through another service: choosing a username
class OauthSignupsController < ApplicationController
  include EmailVerificationFlow

  allow_unauthenticated_access
  before_action :redirect_if_authenticated
  before_action :load_pending
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    @user = User.new(username: @pending["username"])
  end

  def create
    @user = User.new(signup_params)
    # An address the service verified is used as it is, whatever the form says
    @user.email_address = @pending["email"] if @pending["email"]
    @user.display_name = @pending["name"]
    # Nobody knows this password. It can be replaced through "Forgot your password?" or the account page.
    @user.password = SecureRandom.base64(32)
    @user.identities.build(provider: @pending["provider"], uid: @pending["uid"])

    if @user.save
      session.delete(:pending_oauth)
      @user.verify_email! if @pending["email"]
      start_new_session_for @user
      finish_signup
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    session.delete(:pending_oauth)
    redirect_to new_session_path, alert: "That account already belongs to a user. Please log in."
  end

  private
    def redirect_if_authenticated
      redirect_to root_path if authenticated?
    end

    def load_pending
      @pending = session[:pending_oauth]
      return if @pending.is_a?(Hash) && @pending["uid"].present?

      redirect_to new_session_path, alert: "Your sign up expired. Please start again."
    end

    def signup_params
      params.expect(user: [ :username, :email_address ])
    end

    def finish_signup
      if @user.email_verified?
        redirect_to after_authentication_url, notice: "Welcome to Aalam!"
      else
        announce_verification_code(@user)
        redirect_to email_verification_path
      end
    end
end
