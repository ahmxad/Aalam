class Admin::Post < ApplicationRecord
  self.table_name = "posts"

  belongs_to :card, class_name: "Admin::Card"
  validates :card, :title, :summary, :body, presence: true
end
