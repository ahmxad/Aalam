# Helpers for checking the answers that Turbo-powered buttons get
module TurboHelpers
  # The Accept header a browser running Turbo sends when a button is pressed
  TURBO_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  def turbo_headers(extra = {})
    { "Accept" => TURBO_ACCEPT }.merge(extra)
  end

  # The header Turbo sends when a link or form inside a turbo frame asks for its content.
  # With it, only the frame is answered, without the page around it.
  def frame_headers(frame_id, extra = {})
    { "Turbo-Frame" => frame_id }.merge(extra)
  end

  def assert_turbo_stream_response
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  # The answer tells Turbo to do the given action on the element with the given id
  def assert_stream(action, target)
    pattern = /<turbo-stream(?=[^>]*\saction="#{action}")(?=[^>]*\starget="#{Regexp.escape(target)}")[^>]*>/
    assert_match pattern, response.body
  end

  def assert_no_stream_for(target)
    assert_no_match(/target="#{Regexp.escape(target)}"/, response.body)
  end
end
