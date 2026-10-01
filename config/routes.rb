Rails.application.routes.draw do
  namespace :admin do
    resources :posts
  end
  get "posts/:id", to: "pages#show", as: :post_show
  root "pages#home"
  get "home", to: "pages#home"
  get "about", to: "pages#about"
  get "explore", to: "pages#explore"
  get "contact", to: "pages#contact"
  get "up" => "rails/health#show", as: :rails_health_check
end
