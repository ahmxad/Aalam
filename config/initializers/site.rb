# Facts about the site that its legal pages share, kept in one place.
# Change the date whenever the text of the Privacy Policy or the Terms of Use changes.
Rails.application.config.x.legal_updated_on = Date.new(2026, 10, 30)

# Shown on the legal pages next to the link to the Contact page. Nothing is shown while it is empty.
# Set it in the credentials:  site:  contact_email: someone@example.com
Rails.application.config.x.contact_email = Rails.application.credentials.dig(:site, :contact_email).presence

# The address that emails are sent from. Set it in the credentials:
#   site:
#     mail_from: "Aalam <no-reply@yourdomain.com>"
# Without it, the placeholder below is used (fine for development and tests).
Rails.application.config.x.mail_from = Rails.application.credentials.dig(:site, :mail_from).presence || "from@example.com"
