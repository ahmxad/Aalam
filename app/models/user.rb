class User < ApplicationRecord
  RESERVED_USERNAMES = %w[admin administrator root support aalam system me].freeze
  MAX_AVATAR_SIZE = 2.megabytes

  has_secure_password
  has_many :sessions, dependent: :destroy

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 192, 192 ], format: :webp, saver: { quality: 80 }
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip.downcase }
  normalizes :display_name, with: ->(n) { n.strip.presence }
  normalizes :bio, with: ->(b) { b.strip.presence }

  validates :username, presence: true,
                       uniqueness: true,
                       length: { in: 3..20 },
                       format: { with: /\A[a-z0-9_]+\z/, message: "can only contain letters, numbers and underscores" },
                       exclusion: { in: RESERVED_USERNAMES, message: "is not available" }
  validates :display_name, length: { maximum: 50 }
  validates :bio, length: { maximum: 160 }
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :avatar_type_and_size
  validate :avatar_upload_must_be_usable

  # The name shown to other people: display name if set, otherwise the username
  def public_name
    display_name.presence || username
  end

  # True only for a picture that is already saved, not one waiting on a failed form
  def avatar_stored?
    avatar.attached? && avatar.attachment.persisted?
  end

  # A picture chosen in a form. It is converted to a small WebP right away,
  # so the original file is never stored.
  def avatar_upload=(upload)
    return if upload.blank?

    @avatar_upload_error = nil
    self.avatar = AvatarConverter.convert(upload)
  rescue AvatarConverter::InvalidImage => error
    @avatar_upload_error = error.message
  end

  private
    def avatar_type_and_size
      return unless avatar.attached?

      unless avatar.content_type.in?(ImageValidatable::ALLOWED_IMAGE_TYPES)
        errors.add(:avatar, "must be a JPEG, PNG or WebP")
      end

      if avatar.blob.byte_size > MAX_AVATAR_SIZE
        errors.add(:avatar, "must be smaller than 2 MB")
      end
    end
    def avatar_upload_must_be_usable
      errors.add(:avatar, @avatar_upload_error) if @avatar_upload_error
    end
end
