module AvatarsHelper
  # Shows the user's profile picture, or their first letter when there is none
  def user_avatar(user, size_class: "w-12", letter_class: "text-xl")
    if user.avatar_stored?
      tag.div(class: "avatar") do
        tag.div(class: size_class) do
          image_tag user.avatar.variant(:thumb), alt: "#{user.public_name} profile picture", class: "object-cover"
        end
      end
    else
      tag.div(class: "avatar avatar-placeholder") do
        tag.div(class: "bg-base-300 text-base-content #{size_class}") do
          tag.span(user.public_name.first.upcase, class: letter_class)
        end
      end
    end
  end
end
