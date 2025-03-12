require "sidekiq/web"

Rails.application.routes.draw do
  # Admin tools
  mount Sidekiq::Web => "/sidekiq"
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # API namespace for all endpoints
  namespace :api do
    # Authentication & User Management
    namespace :auth do
      post "github/initiate", to: "github#initiate"
      get "github/callback", to: "github#callback"
      delete "logout", to: "sessions#destroy"
    end

    # User Profile & Settings
    get "profile", to: "users#profile"
    put "profile", to: "users#update_profile"

    # Token Management
    namespace :token do
      get "usage", to: "tokens#usage"
      put "settings", to: "tokens#update_settings"
    end

    # User resources with nested contribution endpoints
    resources :users, only: [] do
      collection do
        get :current, to: "users#current_user"
        get :repos, to: "users#user_repos"
        get :contribs, to: "users#fetch_user_contributions"
        get :contributions, to: "contributions#user_contributions"
        get "contributions/history", to: "contributions#user_history"
        get :streaks, to: "contributions#user_streaks"
      end
    end

    # Repository Management
    resources :repositories, only: [ :index, :show, :create ] do
      member do
        get :contributions, to: "contributions#repository_contributions"
        get :qualification
        put :visibility
        post :update_data
      end

      collection do
        get :trending
        get :featured
        post :refresh
        get :search
        get :recommendations
        get :needs_help
      end
    end

    # Leaderboards
    resources :leaderboards, only: [] do
      collection do
        get :global
        get "repository/:id", to: "leaderboards#repository"
      end
    end

    # Webhook management
    resources :webhooks, only: [ :create, :show, :destroy ], param: :repository_id
    post "webhook", to: "webhooks#receive_event", as: :webhook_events
  end
end
