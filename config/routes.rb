Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  resources :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  get "api/auth/github/callback" => "auth/github#callback"
  get "api/profile" => "users#profile"
  get "api/user" => "users#current_user"
  get "api/user/repos" => "users#user_repos"
  get "api/user/contribs" => "users#fetch_user_contributions"
  get "api/data/refresh" => "users#update_repositories_data"
  get "api/data/add" => "users#add_repository"
  get "api/data/updates" => "users#fetch_repo_updates"
end
