# A like on a post or on a comment
class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true, counter_cache: :likes_count

  validates :likeable_id, uniqueness: { scope: [ :user_id, :likeable_type ] }
end
