class EmailVerificationMailer < ApplicationMailer
  def code(user, email, code)
    @user = user
    @code = code
    @expires_in_minutes = EmailVerificationCode::EXPIRES_IN.in_minutes.to_i

    mail to: email, subject: "Your Aalam verification code"
  end
end
