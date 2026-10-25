# A message typed into the contact form. It is never stored, only validated and emailed.
class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  REASONS = { "question" => "Question", "bug" => "Report a bug", "other" => "Other" }.freeze
  MAX_BODY_LENGTH = 3000

  attribute :name, :string
  attribute :email_address, :string
  attribute :reason, :string, default: "question"
  attribute :body, :string
  # Hidden field that people never see. Only bots fill it in.
  attribute :website, :string

  validates :name, presence: true, length: { maximum: 50 },
                   format: { without: /[\r\n]/, message: "can't contain line breaks" }
  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }

  def name=(value)
    super(value.to_s.strip)
  end

  def email_address=(value)
    super(value.to_s.strip.downcase)
  end

  # An unknown reason falls back to a plain question
  def reason=(value)
    super(value.to_s.presence_in(REASONS.keys) || "question")
  end

  def body=(value)
    super(value.to_s.gsub(/\r\n?/, "\n").strip)
  end

  def honeypot_filled?
    website.present?
  end
end
