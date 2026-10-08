class Admin::Topic < ApplicationRecord
  has_one_attached :image

  has_many :cards,
           class_name: "Admin::Card",
           foreign_key: :topic_id,
           dependent: :destroy

  validates :title, presence: true

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = title.to_s.parameterize
  end
end
