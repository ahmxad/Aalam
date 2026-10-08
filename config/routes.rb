Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  namespace :admin do
    resources :topics
    resources :cards
    resources :posts
  end
  get "topics/:topic_slug", to: "pages#topic", as: :topic
  get "topics/:topic_slug/:card_slug", to: "pages#card", as: :topic_card
  get "topics/:topic_slug/:card_slug/:post_slug", to: "pages#show", as: :topic_card_post
  root "pages#home"
  get "home", to: "pages#home"
  get "about", to: "pages#about"
  get "explore", to: "pages#explore"
  get "contact", to: "pages#contact"
  get "up" => "rails/health#show", as: :rails_health_check
end
