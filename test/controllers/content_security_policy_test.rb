require "test_helper"

# The browser enforces these rules. A missing entry breaks a button there without any error on the server,
# which is how the sign in buttons and the picture preview were found broken once.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  # The sources that the page allows for one directive, such as "form-action"
  def sources_for(directive)
    get new_session_path

    header = response.headers["Content-Security-Policy"]
    assert header.present?, "the page should send a Content-Security-Policy header"

    part = header.split(";").map(&:strip).find { |entry| entry.start_with?("#{directive} ") }
    assert part, "the policy has no #{directive} rule"
    part.split.drop(1)
  end

  test "the buttons that sign in through other services may send people to those services" do
    sources = sources_for("form-action")

    assert_includes sources, "'self'"
    assert_includes sources, "https://github.com"
    assert_includes sources, "https://accounts.google.com"
  end

  test "a picture chosen in a form can be previewed from the memory of the browser" do
    assert_includes sources_for("img-src"), "blob:"
  end
end
