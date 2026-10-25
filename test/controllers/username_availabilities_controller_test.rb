require "test_helper"

class UsernameAvailabilitiesControllerTest < ActionDispatch::IntegrationTest
  # Asks the live check and returns its JSON answer
  def check(username)
    get username_availability_path, params: { username: username }

    assert_response :success
    assert_equal "application/json", response.media_type
    response.parsed_body
  end

  test "an unused username is available" do
    result = check("brand_new_name")

    assert_equal true, result["available"]
    assert_equal "Username is available", result["message"]
  end

  test "a taken username is not available" do
    result = check(users(:one).username)

    assert_equal false, result["available"]
    assert_equal "Username has already been taken", result["message"]
  end

  test "case and surrounding spaces do not hide a taken username" do
    result = check("  #{users(:one).username.upcase} ")

    assert_equal false, result["available"]
    assert_equal "Username has already been taken", result["message"]
  end

  test "each rule gives its own message" do
    {
      "ab" => "Username is too short (minimum is 3 characters)",
      "a" * 30 => "Username is too long (maximum is 20 characters)",
      "bad name!" => "Username can only contain letters, numbers and underscores",
      "one@example.com" => "Username can only contain letters, numbers and underscores",
      "admin" => "Username is not available",
      "" => "Username can't be blank"
    }.each do |username, message|
      result = check(username)

      assert_equal false, result["available"], "#{username.inspect} should not be available"
      assert_equal message, result["message"]
    end
  end

  test "a missing username is treated as blank" do
    get username_availability_path

    assert_response :success
    assert_equal false, response.parsed_body["available"]
    assert_equal "Username can't be blank", response.parsed_body["message"]
  end

  test "a huge value is cut down instead of causing an error" do
    result = check("a" * 5000)

    assert_equal false, result["available"]
    assert_equal "Username is too long (maximum is 20 characters)", result["message"]
  end

  test "checking never creates a user" do
    assert_no_difference "User.count" do
      check("brand_new_name")
    end
  end

  test "a signed in user keeping their own username is fine" do
    sign_in_as(users(:one))

    result = check(users(:one).username.upcase)

    assert_equal true, result["available"]
    assert_equal "This is your current username", result["message"]
  end

  test "a signed in user still cannot take someone else's username" do
    sign_in_as(users(:one))

    result = check(users(:two).username)

    assert_equal false, result["available"]
    assert_equal "Username has already been taken", result["message"]
  end
  test "an admin sees a reserved name as available, a normal user does not" do
    sign_in_as(users(:two))
    assert_equal true, check("admin")["available"]

    sign_in_as(users(:one))
    result = check("admin")
    assert_equal false, result["available"]
    assert_equal "Username is not available", result["message"]
  end
end
