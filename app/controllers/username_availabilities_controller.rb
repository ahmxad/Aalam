class UsernameAvailabilitiesController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 60, within: 1.minute, only: :show, with: -> { head :too_many_requests }

  def show
    # An admin may use the reserved names, so the answer has to be the one that saving would give
    admin = authenticated? && Current.session.user.admin?
    user = User.new(username: params[:username].to_s.first(50), admin: admin)

    # A signed in user keeping their own username is fine
    if authenticated? && Current.session.user.username == user.username
      return render json: { available: true, message: "This is your current username" }
    end

    user.validate
    message = user.errors.full_messages_for(:username).first

    render json: { available: message.nil?, message: message || "Username is available" }
  end
end
