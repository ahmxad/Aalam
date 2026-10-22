module VerificationHelper
  # "ahmad@example.com" becomes "a***@example.com", so the page does not show the whole address
  def masked_email(email)
    local, domain = email.to_s.split("@", 2)
    "#{local.to_s.first}***@#{domain}"
  end
end
