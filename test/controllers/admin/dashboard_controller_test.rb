
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "dashboard-admin@test.com",
      password: "password123!",
      admin: true
    )
    sign_in_as(@user)
  end

  test "should get index" do
    get admin_root_url
    assert_response :success
  end
end
