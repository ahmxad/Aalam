# A comment on a post, or a reply to a top level comment
class Comment < ApplicationRecord
  MAX_LENGTH = 1000

  belongs_to :user
  belongs_to :post, class_name: "Admin::Post", counter_cache: :comments_count
  belongs_to :parent, class_name: "Comment", optional: true, counter_cache: :replies_count
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  normalizes :body, with: ->(body) { body.gsub(/\r\n?/, "\n").strip }

  validates :body, presence: true, length: { maximum: MAX_LENGTH }
  validate :parent_must_be_a_top_level_comment_on_the_same_post

  scope :top_level, -> { where(parent_id: nil) }

  def reply?
    parent_id.present?
  end

  private
    # Replies go only one level deep, so a reply to a reply is attached to the comment above it
    def parent_must_be_a_top_level_comment_on_the_same_post
      return unless parent

      errors.add(:parent, "must be a comment on the same post") unless parent.post_id == post_id
      errors.add(:parent, "can't be a reply") if parent.parent_id.present?
    end
end
