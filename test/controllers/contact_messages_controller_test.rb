require "test_helper"

class ContactMessagesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  OWNER_EMAIL = "owner@example.com".freeze

  setup do
    ActionMailer::Base.deliveries.clear
  end

  def using_contact_email(address)
    original = Rails.application.config.x.contact_email
    Rails.application.config.x.contact_email = address
    yield
  ensure
    Rails.application.config.x.contact_email = original
  end

  def valid_params(overrides = {})
    {
      contact_message: {
        name: "Ann",
        email_address: "ann@example.com",
        reason: "question",
        body: "Hello, I have a question."
      }.merge(overrides)
    }
  end

  # The page

  test "the contact page shows the form with every reason" do
    using_contact_email(OWNER_EMAIL) do
      get contact_path

      assert_response :success
      assert_select "form[action=?][method=post]", contact_path
      assert_select "select[name='contact_message[reason]'] option", ContactMessage::REASONS.size
      assert_select "input[name='contact_message[email_address]']"
      assert_select "textarea[name='contact_message[body]']"
    end
  end

  test "the bug link preselects the bug reason" do
    using_contact_email(OWNER_EMAIL) do
      get contact_path(reason: "bug")

      assert_select "select[name='contact_message[reason]'] option[selected][value=bug]"
    end
  end

  test "an unknown reason in the link falls back to a question" do
    using_contact_email(OWNER_EMAIL) do
      get contact_path(reason: "nonsense")

      assert_select "select[name='contact_message[reason]'] option[selected][value=question]"
    end
  end

  test "the page says the form is unavailable when no contact email is set" do
    using_contact_email(nil) do
      get contact_path

      assert_response :success
      assert_select "form[action=?]", contact_path, 0
      assert_select ".alert-warning"
    end
  end

  # Sending

  test "a valid message is emailed to the owner with the visitor as the reply address" do
    using_contact_email(OWNER_EMAIL) do
      perform_enqueued_jobs do
        post contact_path, params: valid_params(reason: "bug")
      end

      assert_redirected_to contact_path
      assert_equal ContactMessagesController::SENT_NOTICE, flash[:notice]

      mail = ActionMailer::Base.deliveries.last
      assert_equal [ OWNER_EMAIL ], mail.to
      assert_equal [ "ann@example.com" ], mail.reply_to
      assert_equal "[Aalam] Report a bug from Ann", mail.subject
      assert_includes mail.body.encoded, "Hello, I have a question."
    end
  end

  test "an unknown reason is sent as a plain question" do
    using_contact_email(OWNER_EMAIL) do
      perform_enqueued_jobs do
        post contact_path, params: valid_params(reason: "nonsense")
      end

      assert_equal "[Aalam] Question from Ann", ActionMailer::Base.deliveries.last.subject
    end
  end

  test "the email address and the name are cleaned up before sending" do
    using_contact_email(OWNER_EMAIL) do
      perform_enqueued_jobs do
        post contact_path, params: valid_params(name: "  Ann  ", email_address: "  ANN@Example.com ")
      end

      mail = ActionMailer::Base.deliveries.last
      assert_equal [ "ann@example.com" ], mail.reply_to
      assert_equal "[Aalam] Question from Ann", mail.subject
    end
  end

  # Rejected messages

  test "an invalid message shows the problems and sends nothing" do
    using_contact_email(OWNER_EMAIL) do
      assert_no_enqueued_emails do
        post contact_path, params: valid_params(email_address: "not-an-email", body: "")
      end

      assert_response :unprocessable_content
      assert_select ".alert-error li", minimum: 2
    end
  end

  test "a name with a line break is rejected, so headers cannot be injected" do
    using_contact_email(OWNER_EMAIL) do
      assert_no_enqueued_emails do
        post contact_path, params: valid_params(name: "Ann\nBcc: someone@example.com")
      end

      assert_response :unprocessable_content
    end
  end

  test "a message that is too long is rejected" do
    using_contact_email(OWNER_EMAIL) do
      assert_no_enqueued_emails do
        post contact_path, params: valid_params(body: "a" * (ContactMessage::MAX_BODY_LENGTH + 1))
      end

      assert_response :unprocessable_content
    end
  end

  test "a filled hidden field looks like success but sends nothing" do
    using_contact_email(OWNER_EMAIL) do
      assert_no_enqueued_emails do
        post contact_path, params: valid_params(website: "http://spam.example")
      end

      assert_redirected_to contact_path
      assert_equal ContactMessagesController::SENT_NOTICE, flash[:notice]
    end
  end

  test "nothing is sent when no contact email is set" do
    using_contact_email(nil) do
      assert_no_enqueued_emails do
        post contact_path, params: valid_params
      end

      assert_redirected_to contact_path
      assert_equal "The contact form is not available right now.", flash[:alert]
    end
  end
end
