require "test_helper"

class Admin::PostMarkdownFormTest < ActionDispatch::IntegrationTest
  setup do
    admin = User.create!(email_address: "markdown-admin@test.com", password: "password123!", admin: true)
    sign_in_as(admin)
  end

  test "the post form can load text from a Markdown file" do
    get new_admin_post_url

    assert_response :success
    assert_select "form[data-controller~='markdown-file']"
    assert_select "form[data-markdown-file-max-chars-value='#{Admin::Post::MAX_BODY_LENGTH}']"
    assert_select "input[type='file'][accept*='.md']:not([name])"
    assert_select "textarea[data-markdown-file-target='body']"
  end
end
