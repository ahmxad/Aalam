class Admin::Card < ApplicationRecord
  # Connects a single image file to this card
  has_one_attached :image

  has_many :posts, class_name: "Admin::Post", dependent: :destroy

  belongs_to :topic, class_name: "Admin::Topic"

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }

  def to_param
      slug
  end

  private

  def generate_slug
      self.slug = title.to_s.parameterize
  end
end
