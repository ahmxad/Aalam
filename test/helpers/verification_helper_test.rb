require "test_helper"

class VerificationHelperTest < ActionView::TestCase
  test "masked_email shows only the first letter of the name" do
    assert_equal "a***@example.com", masked_email("ahmad@example.com")
    assert_equal "j***@mail.co.uk", masked_email("john.doe@mail.co.uk")
  end

  test "masked_email does not fail for a missing address" do
    assert_nothing_raised { masked_email(nil) }
  end
end
