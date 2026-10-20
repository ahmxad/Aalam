require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  def render(text, images: nil)
    MarkdownRenderer.render(text, images: images)
  end

  def uploaded_blob(name = "photo.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/test.png"))),
      filename: name,
      content_type: "image/png"
    )
  end

  # --- Formatting ---

  test "renders headings, bold text and lists" do
    html = render("## Title\n\nSome **bold** text\n\n- one\n- two")

    assert_includes html, "<h2>Title</h2>"
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<li>one</li>"
  end

  test "renders code blocks and tables" do
    html = render("```ruby\nputs 1\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |")

    assert_includes html, "<pre><code"
    assert_includes html, "<table>"
  end

  test "a single line break becomes a line break tag" do
    assert_includes render("line one\nline two"), "line one<br>"
  end

  test "an empty or missing text renders as an empty string" do
    assert_equal "", render(nil)
    assert_equal "", render("").strip
  end

  test "the result is safe to print without escaping again" do
    assert render("hello").html_safe?
  end

  # --- Links ---

  test "links open safely in a new tab" do
    html = render("[site](https://example.com)")

    assert_includes html, 'href="https://example.com"'
    assert_includes html, 'rel="noopener noreferrer nofollow"'
    assert_includes html, 'target="_blank"'
  end

  test "a javascript link does not become a link" do
    html = render("[bad](javascript:alert(1))")

    assert_no_match(/<a\b/, html)
    assert_not_includes html, 'href="javascript'
  end

  # --- Raw HTML is shown as text, never run ---

  test "script tags are escaped" do
    html = render("<script>alert(1)</script>")

    assert_not_includes html, "<script"
    assert_includes html, "&lt;script&gt;"
  end

  test "event handlers on tags are escaped" do
    html = render("<img src=x onerror=alert(1)>")

    assert_not_includes html, "<img"
    assert_includes html, "&lt;img"
  end

  test "iframes and styles are escaped" do
    html = render("<iframe src=\"https://example.com\"></iframe>\n\n<style>body{display:none}</style>")

    assert_not_includes html, "<iframe"
    assert_not_includes html, "<style"
  end

  # --- Images: only the post's own uploads are shown ---

  test "an uploaded image is shown where the text places it" do
    post_record = admin_posts(:one)
    blob = uploaded_blob
    post_record.images.attach(blob)

    html = render("Before\n\n![A picture](/images/#{blob.id})\n\nAfter", images: post_record.images)

    assert_match %r{<img src="/rails/active_storage/representations/[^"]+" alt="A picture" loading="lazy">}, html
    assert_includes html, "<p>Before</p>"
    assert_includes html, "<p>After</p>"
  end

  test "an image address from another website is dropped completely" do
    html = render("Intro\n\n![outside](https://example.com/x.png)\n\nOutro")

    assert_not_includes html, "<img"
    assert_not_includes html, "example.com"
    assert_not_includes html, "outside"
    assert_includes html, "<p>Intro</p>"
    assert_includes html, "<p>Outro</p>"
  end

  test "a file path from the author's computer is dropped completely" do
    html = render("![outside](./pic.png)")

    assert_not_includes html, "pic.png"
    assert_not_includes html, "<img"
    assert_equal "", html.strip
  end

  test "a data address image is dropped" do
    html = render("![x](data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=)")

    assert_not_includes html, "<img"
    assert_not_includes html, "data:"
  end

  test "an image id that does not exist is dropped" do
    html = render("![missing](/images/999999)", images: admin_posts(:one).images)

    assert_not_includes html, "<img"
    assert_equal "", html.strip
  end

  test "an image uploaded for a different post is dropped" do
    other_post = admin_posts(:two)
    blob = uploaded_blob
    other_post.images.attach(blob)

    html = render("![theirs](/images/#{blob.id})", images: admin_posts(:one).images)

    assert_not_includes html, "<img"
  end

    test "the alternative text cannot add markup" do
    post_record = admin_posts(:one)
    blob = uploaded_blob
    post_record.images.attach(blob)

    html = render("![a \"quoted\" <b>bold</b> text](/images/#{blob.id})", images: post_record.images)
    document = Nokogiri::HTML5.fragment(html)

    assert_not_includes html, "<b>"
    assert_empty document.css("b")
    assert_equal 1, document.css("img").size
    assert_equal %(a "quoted" bbold/b text), document.at_css("img")["alt"]
  end
end
