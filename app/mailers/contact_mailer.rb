class ContactMailer < ApplicationMailer
  def message_received(name:, email_address:, reason:, body:)
    @name = name
    @email_address = email_address
    @body = body
    @reason_label = ContactMessage::REASONS.fetch(reason)

    mail to: Rails.application.config.x.contact_email,
         reply_to: email_address,
         subject: "[Aalam] #{@reason_label} from #{name}"
  end
end
