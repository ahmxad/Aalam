class Admin::Topic < ApplicationRecord
  has_one_attached :image

  has_many :cards,
           class_name: "Admin::Card",
           foreign_key: :topic_id,
           dependent: :destroy

  validates :title, presence: true
end
