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
      redirect_to after_authentication_url, notice: "Welcome to Aalam!"
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
end
