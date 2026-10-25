class ProfilesController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @user = User.find_by!(username: params[:username])
    @own_profile = authenticated? && Current.session.user == @user
  end
end
