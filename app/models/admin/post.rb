class Admin::Post < ApplicationRecord
  include SlugHistoryTracking
  MAX_IMAGES = 10
  MAX_BODY_LENGTH = 100_000

  has_many_attached :images do |attachable|
    attachable.variant :inline, resize_to_limit: [ 1200, 1200 ], format: :webp, saver: { quality: 82 }
    attachable.variant :thumb, resize_to_fill: [ 240, 160 ], format: :webp, saver: { quality: 80 }
  end

  validate :images_type_and_size
  self.table_name = "posts"

  belongs_to :card, class_name: "Admin::Card"
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :bookmarks, class_name: "Bookmark", foreign_key: :post_id, dependent: :destroy
  has_many :comments, class_name: "Comment", foreign_key: :post_id, dependent: :destroy
  before_validation :normalize_body_newlines
  validates :card, :title, :summary, :body, presence: true
  validates :body, length: { maximum: MAX_BODY_LENGTH }
  validates :title, uniqueness: { scope: :card_id, case_sensitive: false }

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }
  validates :slug, presence: true
  validates :slug, uniqueness: { scope: :card_id, message: "is already taken in this card" }

  def self.slug_scope_attribute
    :card_id
  end

  def to_param
    id.to_s
  end

  private

  def normalize_body_newlines
    self.body = body.gsub(/\r\n?/, "\n") if body.is_a?(String)
  end

  def images_type_and_size
    errors.add(:images, "can have at most #{MAX_IMAGES} files") if images.size > MAX_IMAGES

    images.each do |image|
      unless image.content_type.in?(ImageValidatable::ALLOWED_IMAGE_TYPES)
        errors.add(:images, "#{image.filename} must be a JPEG, PNG or WebP")
      end

      if image.blob.byte_size > ImageValidatable::MAX_IMAGE_SIZE
        errors.add(:images, "#{image.filename} must be smaller than 5 MB")
      end
    end
  end

  def generate_slug
      self.slug = title.to_s.parameterize
  end
end
