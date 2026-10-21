module EngagementHelper
  ICON_PATHS = {
    like: "M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z",
    save: "M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z"
  }.freeze

  # Whether the signed in user has already liked or saved the post
  def engaged_with?(association, post)
    return false unless authenticated?

    post.public_send(association).exists?(user_id: Current.session.user_id)
  end

  def engagement_icon(name, filled: false)
    tag.svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", class: "h-5 w-5",
            fill: (filled ? "currentColor" : "none"), stroke: "currentColor", "stroke-width": 1.5,
            aria: { hidden: true }) do
      tag.path(d: ICON_PATHS.fetch(name), "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  # A button with an icon and a count. An active button undoes the action when pressed again.
  def engagement_button(path:, active:, icon:, text:, count:)
    button_to path, method: (active ? :delete : :post),
              class: [ "btn btn-sm btn-ghost gap-2", ("text-primary" if active) ],
              aria: { pressed: active, label: "#{text} (#{count})" } do
      safe_join([
        engagement_icon(icon, filled: active),
        tag.span(text, class: "hidden sm:inline"),
        tag.span(number_with_delimiter(count), class: "tabular-nums")
      ])
    end
  end
end
