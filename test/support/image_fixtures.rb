require "tempfile"
require "image_processing/vips"

# Builds small real files for tests, so no binary files are needed in the repository
module ImageFixtures
  IMAGE_TYPES = {
    jpeg: { extension: "jpg", content_type: "image/jpeg" },
    png: { extension: "png", content_type: "image/png" },
    webp: { extension: "webp", content_type: "image/webp" }
  }.freeze

  # A real image of the given type, wrapped like a file chosen in a form
  def uploaded_image(type = :jpeg, width: 40, height: 30, filename: nil)
    details = IMAGE_TYPES.fetch(type)
    source = Tempfile.new([ "image-fixture", ".#{details[:extension]}" ])
    Vips::Image.black(width, height, bands: 3).write_to_file(source.path)

    Rack::Test::UploadedFile.new(
      source.path, details[:content_type], true,
      original_filename: filename || "photo.#{details[:extension]}"
    )
  ensure
    source&.close!
  end

  # Any content at all, for files that are not images or are broken
  def uploaded_file(content, filename:, content_type:)
    source = Tempfile.new([ "file-fixture", File.extname(filename) ], binmode: true)
    source.write(content)
    source.flush

    Rack::Test::UploadedFile.new(source.path, content_type, true, original_filename: filename)
  ensure
    source&.close!
  end

  # [width, height] of an image file or of a Tempfile holding one
  def image_dimensions(file)
    image = Vips::Image.new_from_file(file.respond_to?(:path) ? file.path : file.to_s)
    [ image.width, image.height ]
  end
end
