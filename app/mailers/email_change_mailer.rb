class EmailChangeMailer < ApplicationMailer
  helper VerificationHelper

  # Tells the old address that the account now uses another one
  def notice(user, old_email)
    @user = user

    mail to: old_email, subject: "Your Aalam email address was changed"
  end
end
