require "sidekiq/web"

Rails.application.routes.draw do
  default_url_options host: ENV["APPLICATION_HOST"] || "localhost:3000"

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
    get :reputation_timeline, to: "users#reputation_timeline"

    # Token Management
    namespace :token do
      get "usage", to: "tokens#usage"
      put "settings", to: "tokens#update_settings"
    end

    # Repository Statistics
    resources :repository_stats, only: [ :index, :show ]

    # Analytics using resources
    resources :analytics, only: [] do
      collection do
        get :user
        get :repositories
        get "repository/:id", to: "analytics#repository"
      end
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
        get :pull_requests, to: "pull_requests#user_pull_requests"
        get :issues, to: "issues#user_issues"
      end
    end

    # Topics
    resources :topics, only: [ :index, :show ] do
      member do
        get :repositories
      end
    end

    # Repository Management
    resources :repositories, only: [ :index, :show, :create ] do
      member do
        get :topics
        get :contributions, to: "contributions#repository_contributions"
        get :qualification
        put :visibility
        post :update_data
        get :pull_requests, to: "pull_requests#repository_pull_requests"
        get :issues, to: "issues#repository_issues"
        get :health
        get :activity
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

    # Pull Requests resource
    resources :pull_requests, only: [ :show ]

    # Issues resource
    resources :issues, only: [ :show ]

    # Leaderboards
    resources :leaderboards, only: [] do
      collection do
        get :global
        get "repository/:id", to: "leaderboards#repository"
      end
    end

    # Webhook management
    resources :webhooks, only: [ :create, :show, :destroy ], param: :repository_id
    post :webhook, to: "webhooks#receive_event", as: :webhook_events
  end
end
