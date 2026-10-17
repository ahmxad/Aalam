class Admin::PostsController < Admin::BaseController
  before_action :set_admin_post, only: %i[ show edit update destroy ]
  before_action :set_cards, only: %i[ new create edit update ]

  # GET /admin/posts or /admin/posts.json
  def index
    @topics = Admin::Topic.preload(cards: :posts).order(:title)
  end

  # GET /admin/posts/1 or /admin/posts/1.json
  def show
  end

  # GET /admin/posts/new
  def new
    @admin_post = Admin::Post.new
  end

  # GET /admin/posts/1/edit
  def edit
  end

  # POST /admin/posts or /admin/posts.json
  def create
    @admin_post = Admin::Post.new(admin_post_params)

    respond_to do |format|
      if @admin_post.save
        format.html { redirect_to @admin_post, notice: "Post was successfully created." }
        format.json { render :show, status: :created, location: @admin_post }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @admin_post.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /admin/posts/1 or /admin/posts/1.json
  def update
    respond_to do |format|
      if @admin_post.update(admin_post_params)
        format.html { redirect_to @admin_post, notice: "Post was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @admin_post }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @admin_post.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /admin/posts/1 or /admin/posts/1.json
  def destroy
    @admin_post.destroy!

    respond_to do |format|
      format.html { redirect_to admin_posts_path, notice: "Post was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

def check_slug
  title = params[:title].to_s.strip
  card_id = params[:card_id]

  duplicate = Admin::Post.find_by(
    "LOWER(title) = LOWER(?) AND card_id = ?",
    title,
    card_id
  )

  other_posts = Admin::Post
    .includes(card: :topic)
    .where("LOWER(posts.title) = LOWER(?)", title)
    .where.not(card_id: card_id)

  render json: {
    available: duplicate.nil?,
    existing_cards: other_posts.map do |post|
      "#{post.card.title} (#{post.card.topic.title})"
    end.uniq
  }
end
  private
  # Use callbacks to share common setup or constraints between actions.
  def set_admin_post
    @admin_post = Admin::Post.find(params[:id])
  end

    def set_cards
      @topics = Admin::Topic.preload(:cards).order(:title)
    end

  # Images the admin marked for removal in the form
  # def remove_selected_images
  #   ids = Array(params[:remove_image_ids]).compact_blank
  #   @admin_post.images_attachments.where(id: ids).each(&:purge)
  # end

  # Only allow a list of trusted parameters through.
  def admin_post_params
    params.expect(admin_post: [ :card_id, :title, :summary, :body, images: [] ])
  end
end
