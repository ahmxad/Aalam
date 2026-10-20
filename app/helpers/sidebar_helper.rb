module SidebarHelper
  # The sidebar lists the topics of the public site. It is left out of the admin area, and of the
  # error pages, which must not depend on the database.
  def sidebar_visible?
    !controller_path.start_with?("admin/") && controller_path != "errors"
  end

  # Every topic with its cards, loaded once per request
  def sidebar_topics
    @sidebar_topics ||= Admin::Topic.preload(:cards).order(:title)
  end

  # "open" or "closed" when the visitor chose a state on a wide screen, otherwise nil
  def sidebar_preference
    cookies[:sidebar].presence_in(%w[open closed])
  end
end
