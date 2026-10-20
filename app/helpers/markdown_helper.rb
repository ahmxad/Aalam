module MarkdownHelper
  # Renders Markdown text as safe HTML. Pass the record's images to resolve image:ID references.
  def render_markdown(text, images: nil)
    MarkdownRenderer.render(text, images: images)
  end
end
