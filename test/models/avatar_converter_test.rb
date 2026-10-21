require "test_helper"
require_relative "../support/image_fixtures"

class AvatarConverterTest < ActiveSupport::TestCase
  include ImageFixtures

  test "converts a JPEG to a 512 pixel square WebP" do
    result = AvatarConverter.convert(uploaded_image(:jpeg, width: 1000, height: 600))

    assert_equal "image/webp", result[:content_type]
    assert_equal "avatar.webp", result[:filename]
    assert_equal [ 512, 512 ], image_dimensions(result[:io])
  end

  test "converts a PNG and an existing WebP the same way" do
    [ :png, :webp ].each do |type|
      result = AvatarConverter.convert(uploaded_image(type, width: 800, height: 800))

      assert_equal "image/webp", result[:content_type], "#{type} should become WebP"
      assert_equal [ 512, 512 ], image_dimensions(result[:io])
    end
  end

  test "trusts the file contents, not the file name" do
    result = AvatarConverter.convert(uploaded_image(:png, filename: "looks-like.jpg"))

    assert_equal "image/webp", result[:content_type]
  end

  test "rejects a file that is not an image" do
    upload = uploaded_file("plain text", filename: "avatar.jpg", content_type: "image/jpeg")

    error = assert_raises(AvatarConverter::InvalidImage) { AvatarConverter.convert(upload) }
    assert_equal "must be a JPEG, PNG or WebP", error.message
  end

  test "rejects a file over 10 MB" do
    upload = uploaded_file("a" * 11.megabytes, filename: "huge.jpg", content_type: "image/jpeg")

    error = assert_raises(AvatarConverter::InvalidImage) { AvatarConverter.convert(upload) }
    assert_equal "must be smaller than 10 MB", error.message
  end

  test "rejects an image that looks like a JPEG but is broken" do
    broken = "\xFF\xD8\xFF\xE0".b + ("garbage" * 20).b
    upload = uploaded_file(broken, filename: "broken.jpg", content_type: "image/jpeg")

    error = assert_raises(AvatarConverter::InvalidImage) { AvatarConverter.convert(upload) }
    assert_equal "could not be read as an image", error.message
  end
end
