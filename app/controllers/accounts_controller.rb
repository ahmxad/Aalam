class AccountsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update_password,
             with: -> { redirect_to edit_account_path, alert: "Try again later." }

  rate_limit to: 3, within: 10.minutes, only: :request_password_setup, name: "password_setup",
             with: -> { redirect_to edit_account_path, alert: "Try again later." }

  rate_limit to: 5, within: 10.minutes, only: :request_email_change, name: "email_change",
             with: -> { redirect_to edit_account_path(anchor: "email"), alert: "Try again later." }

  rate_limit to: 5, within: 10.minutes, only: :destroy, name: "account_delete",
             with: -> { redirect_to edit_account_path(anchor: "delete"), alert: "Try again later." }

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

  # Deletes the signed in account. Typing the username is the confirmation, so it works the
  # same for people with a password and for people who only sign in through another service.
  def destroy
    if @user.admin?
      redirect_to edit_account_path(anchor: "delete"), alert: "Admin accounts can't be deleted here."
    elsif params[:confirm_username].to_s.strip.downcase == @user.username
      @user.destroy!
      cookies.delete(:session_id)
      redirect_to root_path, status: :see_other, notice: "Your account has been deleted."
    else
      redirect_to edit_account_path(anchor: "delete"), alert: "The username you typed does not match."
    end
  end

  def destroy_avatar
    @user.avatar.purge_later
    redirect_to edit_account_path, notice: "Profile picture removed."
  end

  # For people who signed up through another service and have no password. The link in the email
  # proves that they can read their inbox, which is what makes it safe to let them set one.
  def request_password_setup
    if @user.password_set?
      redirect_to edit_account_path
    elsif @user.email_verified?
      PasswordsMailer.reset(@user).deliver_later
      redirect_to edit_account_path, notice: "We emailed a link to #{helpers.masked_email(@user.email_address)}."
    else
      redirect_to email_verification_path, alert: "Verify your email first, then we can send the link."
    end
  end

  # Asks to use a new email address. The account keeps the old one until the code sent to the new one is typed in.
  def request_email_change
    candidate = User.new(email_address: params[:email_address].to_s)
    problem = email_change_problem(candidate)
    return redirect_to(edit_account_path(anchor: "email"), alert: problem) if problem

    if EmailVerificationCode.deliver_to(@user, email: candidate.email_address) == :sent
      redirect_to email_verification_path,
                  notice: "We sent a 6 digit code to #{helpers.masked_email(candidate.email_address)}. Enter it to confirm the change."
    else
      redirect_to edit_account_path(anchor: "email"), alert: "We could not send the email. Please try again in a minute."
    end
  rescue EmailVerificationCode::Throttled => error
    redirect_to edit_account_path(anchor: "email"),
                alert: "Please wait #{helpers.distance_of_time_in_words(error.retry_in)} before asking for another code."
  end

  private
    def set_user
      @user = User.find(Current.session.user_id)
    end

    def profile_params
      params.expect(user: [ :username, :display_name, :bio, :avatar_upload ])
    end

    # Returns why the email address cannot be changed to the candidate, or nil when it can
    def email_change_problem(candidate)
      if @user.password_set?
        return "Current password is incorrect." unless @user.authenticate(params[:current_password].to_s)
      elsif @user.email_verified?
        # Without a password, nothing but an open session would stand between a stranger and this account
        return "Set a password first, then you can change your email address."
      end

      return "That is already your email address." if candidate.email_address == @user.email_address

      candidate.validate
      candidate.errors.full_messages_for(:email_address).first&.then { |message| "#{message}." }
    end

    def password_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
end
