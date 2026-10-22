# Shared by the controllers that create an account whose email address still has to be proved
module EmailVerificationFlow
  extend ActiveSupport::Concern

  private
    # The new account must prove its email address before it can like, save or comment
    def announce_verification_code(user)
      if EmailVerificationCode.deliver_to(user) == :sent
        flash[:notice] = "Welcome to Aalam! We sent a 6 digit code to #{helpers.masked_email(user.email_address)}."
      else
        flash[:alert] = "Your account is ready, but we could not send the code. Press \"Send me a code\" to try again."
      end
    end
end
