require "test_helper"

class SocialLoginHelperTest < ActionView::TestCase
  test "a logo sits on a white square so that a dark logo can be seen" do
    badge = Nokogiri::HTML.fragment(provider_logo("github")).at_css("span")

    assert_includes badge["class"].split, "bg-white"

    image = badge.at_css("img")
    assert_equal "", image["alt"]
    assert_equal "true", image["aria-hidden"]
    assert_match %r{social_logos/github.*\.svg\z}, image["src"]
  end

  test "the size can be chosen" do
    badge = Nokogiri::HTML.fragment(provider_logo("google_oauth2", size_class: "h-10 w-10")).at_css("span")

    assert_includes badge["class"].split, "h-10"
    assert_includes badge["class"].split, "w-10"
  end

  test "a service without a logo is an error, not a broken image" do
    assert_raises(KeyError) { provider_logo("facebook") }
  end

  test "every supported service has a logo file that can be found" do
    Identity::PROVIDER_NAMES.each_key do |provider|
      file = SocialLoginHelper::LOGO_FILES.fetch(provider)

      assert Rails.application.assets.load_path.find(file), "#{file} is missing"
    end
  end
end
