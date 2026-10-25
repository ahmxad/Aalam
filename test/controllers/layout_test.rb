require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "public pages include the loading indicator" do
    get root_url

    assert_select ".throbber[role='status'] .throbber__label", text: "Loading"
  end

  test "admin pages include the loading indicator" do
    sign_in_as(User.create!(username: "layout_admin", email_address: "layout-admin@test.com", password: "password123!", admin: true))

    get admin_root_url

    assert_select ".throbber[role='status'] .throbber__label", text: "Loading"
  end
    test "the image loading script is part of the import map" do
    get root_url

    assert_select "script[type='importmap']" do |scripts|
      assert_includes scripts.first.text, "image_loading"
    end
  end
end
