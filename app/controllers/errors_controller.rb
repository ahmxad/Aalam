# Renders the error pages inside the site layout.
#
# It inherits from ActionController::Base on purpose, not from ApplicationController: an error page
# must not need a login, a session or a database query, since it is shown when something already failed.
class ErrorsController < ActionController::Base
    helper_method :authenticated?
    layout "application"

  # The request that failed may be a POST with a rejected token, which must not fail again here
  skip_forgery_protection

  # The plain server error page has no scripts and loads nothing, so it needs no content security policy
  content_security_policy false, if: -> { params[:code].to_s == "500" }

  PAGES = {
    400 => [ "Bad request", "The request could not be understood. Please check the address and try again." ],
    404 => [ "Page not found", "The page you are looking for does not exist, or it has moved." ],
    405 => [ "Not allowed", "That action is not allowed on this page." ],
    406 => [ "Browser not supported", "This page needs a newer browser. Please update yours and try again." ],
    409 => [ "Conflict", "The page changed while you were working on it. Please reload it and try again." ],
    413 => [ "Too large", "What you sent is too large to be accepted." ],
    422 => [ "Request rejected", "Your session may have expired. Please go back, reload the page and try again." ],
    501 => [ "Not available", "This feature is not available." ]
  }.freeze

  def show
    status = params[:code].to_i

    # A server error is shown from a plain file, so it never depends on the layout or the database
    return render(file: Rails.public_path.join("500.html"), layout: false, status: :internal_server_error) if status == 500

    @status = status
    @title, @message = PAGES.fetch(status)
    render :show, status: status, formats: [ :html ]
  end
  private
    # The navbar asks this. An error page must still render when the session or the database
    # is the thing that failed, so any problem here simply counts as signed out.
    def authenticated?
      session_id = cookies.signed[:session_id]
      Current.session ||= Session.find_by(id: session_id) if session_id
      Current.session.present?
    rescue StandardError
      false
    end
end
