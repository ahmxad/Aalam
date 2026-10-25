require "test_helper"

class EmailChangeMailerTest < ActionMailer::TestCase
  setup { @user = users(:one) }

  def build
    EmailChangeMailer.notice(@user, "old-address@example.com")
  end

  test "the notice goes to the old address" do
    mail = build

    assert_equal [ "old-address@example.com" ], mail.to
    assert_equal "Your Aalam email address was changed", mail.subject
  end

  test "it names the account and hides most of the new address" do
    mail = build

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, "@#{@user.username}"
      assert_includes body, "o***@example.com"
      assert_not_includes body, @user.email_address
    end
  end

  test "it tells the person what to do when they did not make the change" do
    assert_includes build.text_part.body.to_s, "If you did not"
  end
end
