# A post a user saved to read again later (shown as "Save" in the interface)
class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :post, class_name: "Admin::Post", counter_cache: :bookmarks_count

  validates :post_id, uniqueness: { scope: :user_id }
end
