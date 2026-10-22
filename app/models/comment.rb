# A comment on a post, or a reply to a top level comment
class Comment < ApplicationRecord
  MAX_LENGTH = 1000
  PAGE_SIZE = 10

  # The ways a list of comments can be ordered. The value is the column that is sorted first,
  # nil means newest first.
  SORT_COLUMNS = { "latest" => nil, "replies" => :replies_count, "likes" => :likes_count }.freeze

  belongs_to :user
  belongs_to :post, class_name: "Admin::Post", counter_cache: :comments_count
  belongs_to :parent, class_name: "Comment", optional: true, counter_cache: :replies_count
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  normalizes :body, with: ->(body) { body.gsub(/\r\n?/, "\n").strip }

  validates :body, presence: true, length: { maximum: MAX_LENGTH }
  validate :parent_must_be_a_top_level_comment_on_the_same_post

  scope :top_level, -> { where(parent_id: nil) }

  # One page of comments in the chosen order. The cursor comes from #cursor_for on the last
  # comment of the previous page, so nothing is repeated or skipped when new comments arrive.
  def self.sorted_page(sort:, cursor: nil, limit: PAGE_SIZE)
    column = SORT_COLUMNS[sort]
    values = cursor_values(cursor, column ? 2 : 1)
    relation = all

    if column
      relation = relation.where("(comments.#{column}, comments.id) < (?, ?)", *values) if values
      relation.order(column => :desc, id: :desc).limit(limit)
    else
      relation = relation.where("comments.id < ?", values.first) if values
      relation.order(id: :desc).limit(limit)
    end
  end

  def self.cursor_values(cursor, size)
    parts = cursor.to_s.split("-")
    return unless parts.size == size && parts.all? { |part| part.match?(/\A\d+\z/) }

    parts.map(&:to_i)
  end
  private_class_method :cursor_values

  def cursor_for(sort)
    column = SORT_COLUMNS[sort]
    column ? "#{self[column]}-#{id}" : id.to_s
  end

  def reply?
    parent_id.present?
  end

  # The author can delete their own comment, and admins can delete any comment
  def deletable_by?(user)
    user.present? && (user_id == user.id || user.admin?)
  end

  private
    # Replies go only one level deep, so a reply to a reply is attached to the comment above it
    def parent_must_be_a_top_level_comment_on_the_same_post
      return unless parent

      errors.add(:parent, "must be a comment on the same post") unless parent.post_id == post_id
      errors.add(:parent, "can't be a reply") if parent.parent_id.present?
    end
end
