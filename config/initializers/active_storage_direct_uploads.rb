# Only signed-in admins may start direct uploads. Without this, the upload endpoint that
# Active Storage adds accepts files from anyone who can reach the site.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    include Authentication

    before_action :require_admin_for_direct_uploads

    private

    # This is a JSON endpoint called by JavaScript, so answer with a status instead of a redirect
    def request_authentication
      head :unauthorized
    end

    def require_admin_for_direct_uploads
      head :forbidden unless Current.session&.user&.admin?
    end
  end
end
