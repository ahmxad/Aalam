class PagesController < ApplicationController
  SEARCH_LIMIT = 20
  MAX_QUERY_LENGTH = 100

  allow_unauthenticated_access

  rate_limit to: 30, within: 1.minute, only: :search,
    with: -> { render plain: "Too many searches. Please wait a minute and try again.", status: :too_many_requests }

  before_action :load_topic, only: %i[topic card show]
  before_action :load_card, only: %i[card show]
  before_action :load_post, only: :show
  before_action :redirect_to_current_url, only: %i[topic card show]

  def home
    @topics = Admin::Topic.with_attached_image.order(created_at: :desc).limit(3)
    @posts = Admin::Post.joins(card: :topic).includes(card: :topic).order(created_at: :desc).limit(3)
  end

  def contact
    @contact_message = ContactMessage.new(reason: params[:reason])
  end

  def explore
    @topics = Admin::Topic.with_attached_image.all
  end

  def about
  end

  def privacy
  end

  def terms
  end

  def show
    siblings = @card.posts
    @previous_post = siblings.where("id < ?", @post.id).order(id: :desc).first
    @next_post = siblings.where("id > ?", @post.id).order(:id).first
  end
  def card
    @posts = @card.posts.order(created_at: :desc)
  end
  def topic
    @cards = @topic.cards.with_attached_image.includes(:posts).order(:title)
  end

  def search
    @query = params[:q].to_s.strip.first(MAX_QUERY_LENGTH)
    return if @query.blank?

    @search_limit = SEARCH_LIMIT
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @topics = Admin::Topic
      .where("title ILIKE ?", pattern)
      .order(:title)
      .limit(SEARCH_LIMIT)
      .load

    @cards = Admin::Card
      .joins(:topic)
      .includes(:topic)
      .where("admin_cards.title ILIKE ?", pattern)
      .order(:title)
      .limit(SEARCH_LIMIT)
      .load

    @posts = Admin::Post
      .joins(card: :topic)
      .includes(card: :topic)
      .where(
        "posts.title ILIKE :q OR posts.summary ILIKE :q OR posts.body ILIKE :q",
        q: pattern
      )
      .order(created_at: :desc)
      .limit(SEARCH_LIMIT)
      .load
  end

  private

  def load_topic
    @topic, outdated = Admin::Topic.find_by_slug_or_history(params[:topic_slug])
    raise ActiveRecord::RecordNotFound unless @topic

    @url_outdated ||= outdated
  end

  def load_card
    @card, outdated = Admin::Card.find_by_slug_or_history(params[:card_slug], scope_id: @topic.id)
    raise ActiveRecord::RecordNotFound unless @card

    @url_outdated ||= outdated
  end

  def load_post
    @post, outdated = Admin::Post.find_by_slug_or_history(params[:post_slug], scope_id: @card.id)
    raise ActiveRecord::RecordNotFound unless @post

    @url_outdated ||= outdated
  end

  # An old URL answers with a permanent redirect to the current URL of the same page
  def redirect_to_current_url
    return unless @url_outdated

    path =
      case action_name
      when "topic" then topic_path(@topic.slug)
      when "card" then topic_card_path(@card.topic.slug, @card.slug)
      else topic_card_post_path(@post.card.topic.slug, @post.card.slug, @post.slug)
      end

    redirect_to path, status: :moved_permanently
  end
end
