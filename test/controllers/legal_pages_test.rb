require "test_helper"
require_relative "../support/omniauth_helpers"

class LegalPagesTest < ActionDispatch::IntegrationTest
  def with_contact_email(address)
    settings = Rails.application.config.x
    previous = settings.contact_email
    settings.contact_email = address
    yield
  ensure
    settings.contact_email = previous
  end

  def legal_pages
    { "Privacy Policy" => privacy_path, "Terms of Use" => terms_path }
  end

  # Opening the pages

  test "anyone can open the Privacy Policy and the Terms of Use" do
    legal_pages.each do |title, path|
      get path

      assert_response :success
      assert_select "title", "#{title} | Aalam"
      assert_select "h1", title
    end
  end

  test "a signed in user can open them too" do
    sign_in_as(users(:one))

    legal_pages.each_value do |path|
      get path

      assert_response :success
    end
  end

  test "both show when they were last updated" do
    date = I18n.l(Rails.application.config.x.legal_updated_on, format: :long)

    legal_pages.each_value do |path|
      get path

      assert_select "header p", text: "Last updated #{date}"
    end
  end

  test "each page has several sections" do
    legal_pages.each_value do |path|
      get path

      assert_select ".article-body h2", minimum: 6
    end
  end

  test "the terms point to the Privacy Policy" do
    get terms_path

    assert_select ".article-body a[href=?]", privacy_path
  end

  # Contact

  test "both point to the Contact page, and show an email address only when one is set" do
    with_contact_email(nil) do
      legal_pages.each_value do |path|
        get path

        assert_select ".article-body a[href=?]", contact_path
        assert_select ".article-body a[href^='mailto:']", 0
      end
    end

    with_contact_email("hello@example.com") do
      legal_pages.each_value do |path|
        get path

        assert_select ".article-body a[href=?]", "mailto:hello@example.com"
      end
    end
  end

  # Where the pages are linked

  test "the footer links to both pages on an ordinary page" do
    get root_path

    assert_select "footer nav[aria-label='Footer links'] a[href=?]", privacy_path, text: "Privacy"
    assert_select "footer nav[aria-label='Footer links'] a[href=?]", terms_path, text: "Terms"
  end

  test "the pages themselves have the footer too" do
    get privacy_path

    assert_select "footer a[href=?]", terms_path
  end

  test "the sign up and log in pages tell people that they agree to both" do
    [ signup_path, new_session_path ].each do |path|
      get path

      assert_select "main a[href=?]", terms_path, text: "Terms of Use"
      assert_select "main a[href=?]", privacy_path, text: "Privacy Policy"
    end
  end

  test "the sign up form says so next to the button that creates the account" do
    get signup_path

    assert_select "form p", text: /By creating an account, you agree to our/
  end

  # The policy has to match what the site really does

  test "the policy names every service that people can sign in with" do
    get privacy_path

    Identity::PROVIDER_NAMES.each_value do |name|
      assert_includes response.body, name
    end
  end

  test "the policy names the font service while the layout loads fonts from it" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read
    skip "the layout no longer loads fonts from Google" unless layout.include?("fonts.googleapis.com")

    get privacy_path

    assert_includes response.body, "Google Fonts"
  end

  test "the policy says there are no analytics, so none may be added without changing it" do
    sources = [ "app/views/layouts/application.html.erb", "config/importmap.rb" ].map { |path| Rails.root.join(path).read }.join

    %w[googletagmanager google-analytics gtag( plausible.io matomo posthog segment.com hotjar].each do |name|
      assert_not_includes sources, name, "#{name} was found: add it to the Privacy Policy, or remove it"
    end
  end
end

class LegalAgreementOnFinishingSignUpTest < ActionDispatch::IntegrationTest
  include OmniauthHelpers

  test "the page for finishing a sign up says that creating the account means agreeing" do
    mock_oauth(:github, uid: "1300", email: "legal@example.com", name: "Legal Person", nickname: "legal_person")
    sign_in_with(:github)

    get new_oauth_signup_path

    assert_select "form p", text: /By creating an account, you agree to our/
    assert_select "form a[href=?]", terms_path
    assert_select "form a[href=?]", privacy_path
  end
end
