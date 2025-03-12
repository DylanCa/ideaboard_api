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
      # POST /api/auth/github/initiate - Initiates GitHub OAuth flow
      post "github/initiate", to: "github#initiate"

      # GET /api/auth/github/callback - OAuth callback handler
      get "github/callback", to: "github#callback"

      # DELETE /api/auth/logout - Invalidates the current user session
      delete "logout", to: "sessions#destroy"
    end

    # User Profile & Settings
    # GET /api/profile - Retrieves user profile
    get "profile", to: "users#profile"

    # PUT /api/profile - Updates user profile settings
    put "profile", to: "users#update_profile"

    # Token Management
    namespace :token do
      # GET /api/token/usage - Retrieves token usage statistics
      get "usage", to: "tokens#usage"

      # PUT /api/token/settings - Updates token usage settings
      put "settings", to: "tokens#update_settings"
    end

    # User-specific endpoints
    get "user", to: "users#current_user"
    get "user/repos", to: "users#user_repos"
    get "user/contribs", to: "users#fetch_user_contributions"

    # Legacy data endpoints
    get "data/refresh", to: "users#update_repositories_data"
    get "data/add", to: "users#add_repository"
    get "data/updates", to: "users#fetch_repo_updates"

    # Webhook management
    post "webhooks", to: "webhooks#create"
    delete "webhooks/:repository_id", to: "webhooks#destroy"
    get "webhooks/:repository_id", to: "webhooks#show"
    post "webhook", to: "webhooks#receive_event", as: :webhook_events
  end
end
