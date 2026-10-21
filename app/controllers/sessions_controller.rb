class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(login_attributes)
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another username, email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
  private
    # The login field accepts either an email address or a username.
    # Usernames can never contain "@" and email addresses always do, so this is unambiguous.
    def login_attributes
      login = params[:login].to_s.strip
      attribute = login.include?("@") ? :email_address : :username
      { attribute => login, password: params[:password].to_s }
    end
end
