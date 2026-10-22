module EngagementHelper
  ICON_PATHS = {
    like: "M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z",
    save: "M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z",
    comment: "M2.25 12.76c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 0 1 1.037-.443 48.282 48.282 0 0 0 5.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z",
    share: "M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
  }.freeze

  # Whether the signed in user has already liked or saved the post
  def engaged_with?(association, post)
    return false unless authenticated?

    post.public_send(association).exists?(user_id: Current.session.user_id)
  end

  def engagement_icon(name, filled: false, size_class: "h-5 w-5")
    tag.svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", class: size_class,
            fill: (filled ? "currentColor" : "none"), stroke: "currentColor", "stroke-width": 1.5,
            aria: { hidden: true }) do
      tag.path(d: ICON_PATHS.fetch(name), "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  # The icon, the label (hidden on small screens) and the count shared by all the buttons
  def engagement_content(icon:, text:, count:, filled: false)
    safe_join([
      engagement_icon(icon, filled: filled),
      tag.span(text, class: "hidden sm:inline"),
      tag.span(number_with_delimiter(count), class: "tabular-nums")
    ])
  end

  # A button that does something and undoes it when pressed again
  def engagement_button(path:, active:, icon:, text:, count:, **options)
    button_to path, method: (active ? :delete : :post),
              class: [ "btn btn-sm btn-ghost gap-2", ("text-primary" if active) ],
              aria: { pressed: active, label: "#{text} (#{count})" }, **options do
      engagement_content(icon: icon, text: text, count: count, filled: active)
    end
  end

  # A link that looks like the buttons, for things that open instead of changing data
  def engagement_link(path:, icon:, text:, count:, **options)
    link_to path, class: "btn btn-sm btn-ghost gap-2", aria: { label: "#{text} (#{count})" }, **options do
      engagement_content(icon: icon, text: text, count: count)
    end
  end
end
