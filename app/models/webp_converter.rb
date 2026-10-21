# Converts a JPEG or PNG picked in a form into a WebP file, so only the WebP is stored.
# Anything it cannot or should not convert (a WebP, a file that is too big, a broken image,
# a direct upload) is handed back unchanged, so the normal validations still apply.
class WebpConverter
  CONVERTIBLE_TYPES = %w[image/jpeg image/png].freeze
  MAX_INPUT_SIZE = ImageValidatable::MAX_IMAGE_SIZE
  MAX_DIMENSION = 2400
  JPEG_QUALITY = 90

  def self.convert(attachable)
    return attachable unless attachable.respond_to?(:tempfile)
    return attachable if attachable.size > MAX_INPUT_SIZE

    type = detected_type(attachable)
    return attachable unless CONVERTIBLE_TYPES.include?(type)

    process(attachable, lossless: type == "image/png")
  end

  # Looks at the real file contents, not at the type the browser claims
  def self.detected_type(upload)
    Marcel::MimeType.for(upload.tempfile).tap { upload.tempfile.rewind }
  end
  private_class_method :detected_type

  def self.process(upload, lossless:)
    saver = lossless ? { lossless: true, strip: true } : { quality: JPEG_QUALITY, strip: true }

    converted = ImageProcessing::Vips
      .source(upload.tempfile.path)
      .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
      .convert("webp")
      .saver(**saver)
      .call

    filename = "#{File.basename(upload.original_filename.to_s, '.*')}.webp"
    { io: converted, filename: filename, content_type: "image/webp" }
  rescue Vips::Error, ImageProcessing::Error => error
    Rails.logger.warn("WebP conversion skipped: #{error.message}")
    upload
  end
  private_class_method :process
end
