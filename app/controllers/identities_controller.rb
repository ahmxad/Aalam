# Removes a connected service (such as GitHub) from the signed in user's account
class IdentitiesController < ApplicationController
  def destroy
    user = Current.session.user
    message = nil

    # The user is locked, so two disconnects at the same moment cannot remove every way to sign in
    user.with_lock do
      identity = user.identities.find(params[:id])

      if user.can_disconnect?(identity)
        identity.destroy
        message = [ :notice, "#{identity.provider_name} was disconnected." ]
      else
        message = [ :alert, "#{identity.provider_name} is your only way to sign in. Set a password first." ]
      end
    end

    redirect_to edit_account_path, status: :see_other, message.first => message.last
  end
end
