require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "the content security policy is enforced, not only reported" do
    get root_url

    assert_response :success
    assert response.headers["Content-Security-Policy"].present?
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end

  test "a visitor without a session gets a fresh nonce on every request" do
    get root_url
    first_nonce = response.body[/nonce="([^"]+)"/, 1]

    get root_url
    second_nonce = response.body[/nonce="([^"]+)"/, 1]

    assert first_nonce.present?
    assert_not_equal first_nonce, second_nonce
    assert_includes response.headers["Content-Security-Policy"], "'nonce-#{second_nonce}'"
  end

  test "only the site itself may run scripts and nothing may be embedded as an object" do
    get root_url
    policy = response.headers["Content-Security-Policy"]

    assert_includes policy, "script-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "frame-ancestors 'self'"
  end
end
