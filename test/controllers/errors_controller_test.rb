require "test_helper"

class ErrorsControllerTest < ActionController::TestCase
  test "the 404 page uses the site layout and needs no login" do
    get :show, params: { code: 404 }

    assert_response :not_found
    assert_select "h1", text: "Page not found"
    assert_select "nav[aria-label='Main']"
    assert_select "footer"
  end

  test "the 422 page explains that the request was rejected" do
    get :show, params: { code: 422 }

    assert_response 422
    assert_select "h1", text: "Request rejected"
  end

  test "the 400 page" do
    get :show, params: { code: 400 }

    assert_response 400
    assert_select "h1", text: "Bad request"
  end

  test "the server error page is the plain file and does not use the layout" do
    get :show, params: { code: 500 }

    assert_response 500
    assert_includes response.body, "Error 500"
    assert_not_includes response.body, "throbber"
  end
end
