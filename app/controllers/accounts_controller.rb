class AccountsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update_password,
             with: -> { redirect_to edit_account_path, alert: "Try again later." }

  # Works on its own copy of the signed in user. The navbar uses Current.session.user,
  # so a form that fails validation must never leave unsaved values on that object.
  before_action :set_user

  def edit
  end

  def update
    if @user.update(profile_params)
      redirect_to profile_path(@user.username), notice: "Profile updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def update_password
    attributes = password_params

    if !@user.authenticate(attributes[:current_password])
      @user.errors.add(:base, "Current password is incorrect")
    elsif attributes[:password].blank?
      @user.errors.add(:base, "New password can't be blank")
    elsif @user.update(attributes.slice(:password, :password_confirmation))
      # Log out every other device, keep the current one
      @user.sessions.where.not(id: Current.session.id).destroy_all
      return redirect_to edit_account_path, notice: "Password updated."
    end

    render :edit, status: :unprocessable_content
  end

  def destroy_avatar
    @user.avatar.purge_later
    redirect_to edit_account_path, notice: "Profile picture removed."
  end

  private
    def set_user
      @user = User.find(Current.session.user_id)
    end

    def profile_params
      params.expect(user: [ :username, :display_name, :bio, :avatar_upload ])
    end

    def password_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
end
