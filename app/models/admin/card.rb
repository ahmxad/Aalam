class Admin::Card < ApplicationRecord
  # Connects a single image file to this card
  include ImageValidatable
  has_one_attached :image do |attachable|
    attachable.variant :card, resize_to_fill: [ 600, 320 ], format: :webp, saver: { quality: 80 }
    attachable.variant :thumb, resize_to_limit: [ 512, 512 ], format: :webp, saver: { quality: 80 }
    attachable.variant :hero, resize_to_fill: [ 1600, 640 ], format: :webp, saver: { quality: 80 }
  end

  has_many :posts, class_name: "Admin::Post", dependent: :destroy

  belongs_to :topic, class_name: "Admin::Topic"

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }
  validates :title, :slug, presence: true
  validates :slug, uniqueness: { scope: :topic_id, message: "is already taken in this topic" }

  def to_param
    id.to_s
  end

  private

  def generate_slug
      self.slug = title.to_s.parameterize
  end
end
