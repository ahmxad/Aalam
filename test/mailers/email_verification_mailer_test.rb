require "test_helper"

class EmailVerificationMailerTest < ActionMailer::TestCase
  setup { @user = users(:one) }

  def build(code = "123456", to: "target@example.com")
    EmailVerificationMailer.code(@user, to, code)
  end

  test "the email goes to the given address with a clear subject" do
    mail = build

    assert_equal [ "target@example.com" ], mail.to
    assert_equal "Your Aalam verification code", mail.subject
    assert mail.from.present?
  end

  test "the HTML and the text version both show the code and how long it lasts" do
    mail = build("482913")

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, "482913"
      assert_includes body, "10 minutes"
      assert_includes body, @user.public_name
    end
  end

  test "the email says what to do when the code was not asked for" do
    assert_includes build.text_part.body.to_s, "did not ask for this code"
  end

  test "the name of the user is escaped in the HTML version" do
    @user.update!(display_name: "<b>Bold</b>")

    html = build.html_part.body.to_s

    assert_not_includes html, "<b>Bold</b>"
    assert_includes html, "&lt;b&gt;Bold&lt;/b&gt;"
  end

  test "delivering it puts one email in the outbox" do
    assert_emails 1 do
      build.deliver_now
    end
  end
end
