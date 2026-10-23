Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  resource :session
  resource :registration, only: %i[new create]
  resource :email_verification, path: "verify-email", only: %i[show create destroy] do
    post :resend
  end
  resource :username_availability, only: :show
  resource :account, only: %i[edit update]
  patch "account/password", to: "accounts#update_password", as: :account_password
  post "account/password/setup", to: "accounts#request_password_setup", as: :account_password_setup
  post "account/email", to: "accounts#request_email_change", as: :account_email
  resources :identities, only: :destroy
  get "u/:username", to: "profiles#show", as: :profile, constraints: { username: /[A-Za-z0-9_]+/ }
  get "auth/failure", to: "omniauth_callbacks#failure"
  get "auth/:provider/callback", to: "omniauth_callbacks#create", constraints: { provider: /github|google_oauth2/ }
  get "signup/finish", to: "oauth_signups#new", as: :new_oauth_signup
  post "signup/finish", to: "oauth_signups#create", as: :oauth_signup
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
