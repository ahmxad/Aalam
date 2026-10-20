# Turns Markdown written by an admin into safe HTML.
#
# Two layers protect visitors: the Markdown renderer escapes raw HTML and blocks unsafe
# links, then the result is sanitized again against a short allow list of tags and attributes.
#
# Images are written as ![alt](/images/12), where 12 is the id of an image uploaded for the post.
# Only the post's own images are shown. Any other image reference (another website, a file path
# on the author's computer, a data address or an unknown id) is dropped completely.
class MarkdownRenderer
  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6 p br hr strong em del code pre blockquote
    ul ol li a img table thead tbody tr th td
  ].freeze

  ALLOWED_ATTRIBUTES = %w[href src alt title rel target loading].freeze

  RENDERER_OPTIONS = {
    escape_html: true,
    safe_links_only: true,
    hard_wrap: true,
    link_attributes: { rel: "noopener noreferrer nofollow", target: "_blank" }
  }.freeze

  EXTENSIONS = {
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    no_intra_emphasis: true
  }.freeze

  IMAGE_REFERENCE = %r{\A/images/(\d+)\z}

  # Writes the image tags itself, so that an image which is not one of the post's uploads
  # produces nothing at all instead of showing its Markdown as text
  class HtmlRenderer < Redcarpet::Render::HTML
    def initialize(attachments, options = {})
      super(options)
      @attachments = attachments
    end

    def image(link, _title, alt_text)
      attachment = @attachments[link.to_s[IMAGE_REFERENCE, 1]&.to_i]
      return "" unless attachment

      src = ERB::Util.html_escape(image_path_for(attachment))
      alt = ERB::Util.html_escape(alt_text.to_s.delete("<>"))
      %(<img src="#{src}" alt="#{alt}" loading="lazy">)
    end

    private

    def image_path_for(attachment)
      routes = Rails.application.routes.url_helpers

      if attachment.blob.variable?
        routes.rails_representation_path(attachment.variant(:inline), only_path: true)
      else
        routes.rails_blob_path(attachment, only_path: true)
      end
    end
  end

  # images: the post's attached images (post.images), used to resolve /images/ID references
  def self.render(text, images: nil)
    new(images).render(text)
  end

  def initialize(images = nil)
    @attachments = images ? images.attachments.index_by(&:blob_id) : {}
  end

  def render(text)
    html = remove_empty_paragraphs(markdown.render(text.to_s))
    ActionController::Base.helpers.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end

  private

  def markdown
    Redcarpet::Markdown.new(HtmlRenderer.new(@attachments, RENDERER_OPTIONS), EXTENSIONS)
  end

  # A paragraph that only held a dropped image would leave an empty gap
  def remove_empty_paragraphs(html)
    fragment = Nokogiri::HTML5.fragment(html)

    fragment.css("p").each do |paragraph|
      paragraph.remove if paragraph.content.strip.empty? && paragraph.element_children.empty?
    end

    fragment.to_html
  end
end
