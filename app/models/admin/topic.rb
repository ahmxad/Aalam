class Admin::Topic < ApplicationRecord
  include SlugHistoryTracking
  include ImageValidatable
  has_one_attached :image do |attachable|
    attachable.variant :card, resize_to_fill: [ 600, 320 ], format: :webp, saver: { quality: 80 }
    attachable.variant :hero, resize_to_fill: [ 1600, 640 ], format: :webp, saver: { quality: 80 }
  end

  has_many :cards,
           class_name: "Admin::Card",
           foreign_key: :topic_id,
           dependent: :destroy

  validates :title, presence: true
  validates :slug,
            presence: { message: "could not be generated: include at least one Latin letter or digit in the title" },
            uniqueness: { allow_blank: true }

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = title.to_s.parameterize
  end
end
