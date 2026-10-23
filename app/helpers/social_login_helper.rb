module SocialLoginHelper
  LOGO_FILES = { "github" => "social_logos/github.svg", "google_oauth2" => "social_logos/google.svg" }.freeze

  # A service's logo on a white square, so a dark logo can still be seen on the dark theme
  def provider_logo(provider, size_class: "h-6 w-6")
    tag.span(class: "inline-flex shrink-0 items-center justify-center bg-white p-1 #{size_class}") do
      image_tag(LOGO_FILES.fetch(provider), alt: "", class: "h-full w-full object-contain", aria: { hidden: true })
    end
  end
end
