class Admin::Post < ApplicationRecord
  include SlugHistoryTracking
  self.table_name = "posts"

  belongs_to :card, class_name: "Admin::Card"
  validates :card, :title, :summary, :body, presence: true
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

  def generate_slug
      self.slug = title.to_s.parameterize
  end
end
