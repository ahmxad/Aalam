module ImageValidatable
  extend ActiveSupport::Concern

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  included do
    validate :image_type_and_size
    validate :image_must_be_attached, on: :create
  end

  private

  def image_type_and_size
    return unless image.attached?

    unless image.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:image, "must be a JPEG, PNG or WebP")
    end

    if image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:image, "must be smaller than 5 MB")
    end
  end
  def image_must_be_attached
    errors.add(:image, "must be attached") unless image.attached?
  end
end
