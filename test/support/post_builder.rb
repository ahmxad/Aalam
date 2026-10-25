require "securerandom"
require_relative "image_fixtures"

# Builds the topic, card and post that the post page and the buttons under it need
module PostBuilder
  include ImageFixtures

  def create_card
    suffix = SecureRandom.hex(3)
    topic = Admin::Topic.create!(title: "Topic #{suffix}", image: uploaded_image(:webp))
    Admin::Card.create!(topic: topic, title: "Card #{suffix}", image: uploaded_image(:webp))
  end

  def create_post(card: create_card, title: "Post #{SecureRandom.hex(3)}")
    Admin::Post.create!(card: card, title: title, summary: "A short summary", body: "Some text for the post.")
  end

  # The address of the post page, which is where the buttons send people back to
  def post_page_path_for(post)
    topic_card_post_path(post.card.topic.slug, post.card.slug, post.slug)
  end
  def create_comment(post, body = "A comment", user: users(:one), parent: nil)
    Comment.create!(user: user, post: post, parent: parent, body: body)
  end

  # A person who is neither the author of the comments nor an admin
  def create_user(username = "person_#{SecureRandom.hex(3)}")
    User.create!(username: username, email_address: "#{username}@example.com", password: "password123")
  end
  # A person who signed up but has not proved their email address yet
  def create_unverified_user(username = "person_#{SecureRandom.hex(3)}")
    create_user(username)
  end
  # A person who signed up through other services and has no password of their own
  def create_oauth_user(username = "oauth_only", providers: %w[github], verified: true)
    user = create_user(username)
    user.update_columns(password_set: false)
    user.verify_email! if verified
    providers.each { |provider| user.identities.create!(provider: provider, uid: "#{provider}_#{username}") }
    user
  end
end
