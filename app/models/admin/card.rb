class Admin::Card < ApplicationRecord
  # Connects a single image file to this card
  has_one_attached :image

  has_many :posts, class_name: "Admin::Post", dependent: :destroy

  belongs_to :topic, class_name: "Admin::Topic"

end
