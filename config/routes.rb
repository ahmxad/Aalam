Rails.application.routes.draw do
  root "home#index"
  get "home", to: "home#index"
  get "explore", to: "explore#index"
  get "contact", to: "contact#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
