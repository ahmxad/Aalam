class Admin::CardsController < Admin::BaseController
  before_action :set_admin_card, only: %i[ show edit update destroy ]

  # GET /admin/cards or /admin/cards.json
  def index
    # Optimization: Use .with_attached_image to prevent N+1 query performance database slowdowns
    @admin_cards = Admin::Card.with_attached_image.all
  end

  # GET /admin/cards/1 or /admin/cards/1.json
  def show
  end

  # GET /admin/cards/new
  def new
    @admin_card = Admin::Card.new
    @topics = Admin::Topic.all
  end

  # GET /admin/cards/1/edit
  def edit
    @topics = Admin::Topic.all
  end

  # POST /admin/cards or /admin/cards.json
  # POST /admin/cards or /admin/cards.json
  def create
    @admin_card = Admin::Card.new(admin_card_params)

    respond_to do |format|
      if @admin_card.save
        # FIX: Use the specific route helper suggested by Rails
        format.html { redirect_to admin_card_path(@admin_card), notice: "Card was successfully created." }
        format.json { render :show, status: :created, location: admin_card_path(@admin_card) }
      else
        @topics = Admin::Topic.all
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @admin_card.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /admin/cards/1 or /admin/cards/1.json
  def update
    respond_to do |format|
      if @admin_card.update(admin_card_params)
        # FIX: Use the specific route helper here as well
        format.html { redirect_to admin_card_path(@admin_card), notice: "Card was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: admin_card_path(@admin_card) }
      else
        @topics = Admin::Topic.all
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @admin_card.errors, status: :unprocessable_content }
      end
    end
  end


  # DELETE /admin/cards/1 or /admin/cards/1.json
  def destroy
    @admin_card.destroy!

    respond_to do |format|
      format.html { redirect_to admin_cards_path, notice: "Card was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_admin_card
    @admin_card = Admin::Card.find_by!(slug: params[:id])
  end

    # Only allow a list of trusted parameters through.
    def admin_card_params
      # ADDED: Added :image into the permitted attributes array
      params.expect(admin_card: [ :title, :image, :topic_id ])
    end
end
