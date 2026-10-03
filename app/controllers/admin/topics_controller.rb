class Admin::TopicsController < Admin::BaseController
  before_action :set_admin_topic, only: %i[ show edit update destroy ]

  # GET /admin/topics or /admin/topics.json
  def index
    @admin_topics = Admin::Topic.all
  end

  # GET /admin/topics/1 or /admin/topics/1.json
  def show
  end

  # GET /admin/topics/new
  def new
    @admin_topic = Admin::Topic.new
  end

  # GET /admin/topics/1/edit
  def edit
  end

  # POST /admin/topics or /admin/topics.json
  def create
    @admin_topic = Admin::Topic.new(admin_topic_params)

    respond_to do |format|
      if @admin_topic.save
        format.html { redirect_to @admin_topic, notice: "Topic was successfully created." }
        format.json { render :show, status: :created, location: @admin_topic }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @admin_topic.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /admin/topics/1 or /admin/topics/1.json
  def update
    respond_to do |format|
      if @admin_topic.update(admin_topic_params)
        format.html { redirect_to @admin_topic, notice: "Topic was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @admin_topic }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @admin_topic.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /admin/topics/1 or /admin/topics/1.json
  def destroy
    @admin_topic.destroy!

    respond_to do |format|
      format.html { redirect_to admin_topics_path, notice: "Topic was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_topic
      @admin_topic = Admin::Topic.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def admin_topic_params
      params.expect(admin_topic: [ :title, :image ])
    end
end
