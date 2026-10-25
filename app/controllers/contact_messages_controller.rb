class ContactMessagesController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 3, within: 10.minutes, only: :create,
             with: -> { redirect_to contact_path, alert: "Too many messages. Please try again later." }

  SENT_NOTICE = "Thank you! Your message has been sent.".freeze

  def create
    @contact_message = ContactMessage.new(contact_message_params)

    if Rails.application.config.x.contact_email.blank?
      redirect_to contact_path, alert: "The contact form is not available right now."
    elsif @contact_message.honeypot_filled?
      # Pretend it worked so a bot learns nothing, but send nothing
      redirect_to contact_path, notice: SENT_NOTICE
    elsif @contact_message.valid?
      ContactMailer.message_received(
        name: @contact_message.name,
        email_address: @contact_message.email_address,
        reason: @contact_message.reason,
        body: @contact_message.body
      ).deliver_later
      redirect_to contact_path, notice: SENT_NOTICE
    else
      render "pages/contact", status: :unprocessable_content
    end
  end

  private
    def contact_message_params
      params.expect(contact_message: [ :name, :email_address, :reason, :body, :website ])
    end
end
