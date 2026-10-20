require "test_helper"

# The whole flow: a request that fails ends up on the site's error page, as it does in production
class ErrorPagesTest < ActionDispatch::IntegrationTest
  setup do
    # The test environment shows Rails' detailed debug page, which visitors never see
    @detailed_exceptions = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    @show_exceptions = Rails.application.env_config["action_dispatch.show_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed_exceptions
    Rails.application.env_config["action_dispatch.show_exceptions"] = @show_exceptions
  end

  test "an unknown address shows the 404 page inside the site layout" do
    get "/no/such/page"

    assert_response :not_found
    assert_select "h1", text: "Page not found"
    assert_select "nav[aria-label='Main']"
    assert_select "footer"
  end

  test "a missing topic shows the 404 page" do
    get topic_url("never-existed")

    assert_response :not_found
    assert_select "h1", text: "Page not found"
  end

  test "a missing record in the admin area shows the 404 page" do
    sign_in_as(User.create!(email_address: "errors-admin@test.com", password: "password123!", admin: true))

    get admin_topic_url("never-existed")

    assert_response :not_found
    assert_select "h1", text: "Page not found"
  end

  test "a missing file of another type gets a 404, not a server error" do
    get "/missing.png"

    assert_response :not_found
  end

  test "an unlisted status code is not an error page" do
    get "/599"

    assert_response :not_found
    assert_select "h1", text: "Page not found"
  end
  test "an unexpected failure ends on the plain server error page" do
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all

    # Make a real failure happen inside the app, and always put the original method back
    original = Admin::Topic.method(:find_by_slug_or_history)
    Admin::Topic.define_singleton_method(:find_by_slug_or_history) { |*, **| raise "boom" }

    begin
      get topic_url("anything")
    ensure
      Admin::Topic.define_singleton_method(:find_by_slug_or_history, original)
    end

    assert_response :internal_server_error
    assert_includes response.body, "Error 500"
    assert_not_includes response.body, "throbber"
  end
end
