require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "new links to the sign up page" do
    get new_session_path
    assert_select "a[href=?]", signup_path, text: "Create one"
  end

  test "create with an email address" do
    post session_path, params: { login: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with a username" do
    post session_path, params: { login: @user.username, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with a username in a different case" do
    post session_path, params: { login: @user.username.upcase, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with a wrong password" do
    post session_path, params: { login: @user.username, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create with an unknown login" do
    post session_path, params: { login: "nobody_here", password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
