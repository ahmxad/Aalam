class Admin::Post < ApplicationRecord
  self.table_name = "posts"

  belongs_to :card, class_name: "Admin::Card"
  validates :card, :title, :summary, :body, presence: true

  before_validation :generate_slug, if: -> { slug.blank? || will_save_change_to_title? }

  def to_param
      slug
  end

  private

  def generate_slug
      self.slug = title.to_s.parameterize
  end
end
