# Turns a picture chosen by a user into the small square WebP that is stored as their avatar.
# The original upload is never kept.
class AvatarConverter
  class InvalidImage < StandardError; end

  MAX_UPLOAD_SIZE = 10.megabytes
  OUTPUT_SIZE = 512
  OUTPUT_QUALITY = 80

  def self.convert(upload)
    new(upload).convert
  end

  def initialize(upload)
    @upload = upload
  end

  def convert
    raise InvalidImage, "must be a JPEG, PNG or WebP" unless @upload.respond_to?(:tempfile)

    check_size
    check_type
    process
  end

  private
    def check_size
      return if @upload.size <= MAX_UPLOAD_SIZE

      raise InvalidImage, "must be smaller than #{MAX_UPLOAD_SIZE / 1.megabyte} MB"
    end

    # Looks at the real file contents, not at the name or type the browser claims
    def check_type
      detected = Marcel::MimeType.for(@upload.tempfile)
      @upload.tempfile.rewind
      return if detected.in?(ImageValidatable::ALLOWED_IMAGE_TYPES)

      raise InvalidImage, "must be a JPEG, PNG or WebP"
    end

    def process
      converted = ImageProcessing::Vips
        .source(@upload.tempfile.path)
        .resize_to_fill(OUTPUT_SIZE, OUTPUT_SIZE)
        .convert("webp")
        .saver(quality: OUTPUT_QUALITY, strip: true)
        .call

      { io: converted, filename: "avatar.webp", content_type: "image/webp" }
    rescue Vips::Error, ImageProcessing::Error
      raise InvalidImage, "could not be read as an image"
    end
end
