require "test_helper"
require_relative "../support/image_fixtures"

class WebpConverterTest < ActiveSupport::TestCase
  include ImageFixtures

  test "converts a JPEG to WebP and keeps its size" do
    result = WebpConverter.convert(uploaded_image(:jpeg, width: 300, height: 200, filename: "photo.jpg"))

    assert_equal "image/webp", result[:content_type]
    assert_equal "photo.webp", result[:filename]
    assert_equal [ 300, 200 ], image_dimensions(result[:io])
  end

  test "converts a PNG to WebP" do
    result = WebpConverter.convert(uploaded_image(:png, filename: "screenshot.png"))

    assert_equal "image/webp", result[:content_type]
    assert_equal "screenshot.webp", result[:filename]
  end

  test "shrinks a very large picture to 2400 pixels on its longest side" do
    result = WebpConverter.convert(uploaded_image(:jpeg, width: 3000, height: 1000))

    assert_equal [ 2400, 800 ], image_dimensions(result[:io])
  end

  test "leaves a WebP untouched" do
    upload = uploaded_image(:webp)

    assert_same upload, WebpConverter.convert(upload)
  end

  test "leaves things that are not plain file uploads untouched" do
    assert_nil WebpConverter.convert(nil)
    assert_equal "a-signed-blob-id", WebpConverter.convert("a-signed-blob-id")

    attachable = { io: StringIO.new("x"), filename: "x.jpg" }
    assert_same attachable, WebpConverter.convert(attachable)
  end

  test "leaves a file over 5 MB untouched, so the normal validation can reject it" do
    upload = uploaded_file("a" * 6.megabytes, filename: "huge.jpg", content_type: "image/jpeg")

    assert_same upload, WebpConverter.convert(upload)
  end

  test "leaves a file that is not an image untouched" do
    upload = uploaded_file("plain text", filename: "notes.jpg", content_type: "image/jpeg")

    assert_same upload, WebpConverter.convert(upload)
  end

  test "leaves a broken image untouched instead of failing" do
    broken = "\xFF\xD8\xFF\xE0".b + ("garbage" * 20).b
    upload = uploaded_file(broken, filename: "broken.jpg", content_type: "image/jpeg")

    assert_same upload, WebpConverter.convert(upload)
  end
end
