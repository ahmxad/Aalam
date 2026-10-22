Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  resource :session
  resource :registration, only: %i[new create]
  resource :email_verification, path: "verify-email", only: %i[show create] do
    post :resend
  end
  resource :username_availability, only: :show
  resource :account, only: %i[edit update]
  patch "account/password", to: "accounts#update_password", as: :account_password
  get "u/:username", to: "profiles#show", as: :profile, constraints: { username: /[A-Za-z0-9_]+/ }
  get "saved", to: "saved_posts#index", as: :saved_posts
  resources :posts, only: [] do
    resource :like, only: %i[create destroy]
    resource :bookmark, only: %i[create destroy]
    resources :comments, only: %i[index create]
    resource :share, only: :create
  end
  resources :comments, only: :destroy do
    resources :replies, only: %i[index create]
    resource :like, only: %i[create destroy], controller: "comment_likes"
  end
  delete "account/avatar", to: "accounts#destroy_avatar", as: :account_avatar
  get "signup", to: "registrations#new", as: :signup
  resources :passwords, param: :token
  namespace :admin do
    root "dashboard#index"
    post "maintenance/unused_images", to: "maintenance#purge_unused_images", as: :purge_unused_images
    get "topics/check_slug", to: "topics#check_slug"
    get "cards/check_slug", to: "cards#check_slug"
    get "posts/check_slug", to: "posts#check_slug"
    resources :topics
    resources :cards
    resources :posts
  end
  get "topics/:topic_slug", to: "pages#topic", as: :topic
  get "topics/:topic_slug/:card_slug", to: "pages#card", as: :topic_card
  get "topics/:topic_slug/:card_slug/:post_slug", to: "pages#show", as: :topic_card_post
  get "search", to: "pages#search", as: :search
  root "pages#home"
  get "home", to: "pages#home"
  get "about", to: "pages#about"
  get "explore", to: "pages#explore"
  get "contact", to: "pages#contact"
  get "up" => "rails/health#show", as: :rails_health_check
  # Error pages, shown through config.exceptions_app. They can also be opened directly to preview them.
  match "/:code", to: "errors#show", via: :all, constraints: { code: /400|404|405|406|409|413|422|500|501/ }
end
