module Api
  class UsersController < ApplicationController
    include Api::Concerns::JwtAuthenticable

    def current_user
      result = Github::GraphqlService.fetch_current_user_data(@current_user)
      render json: { data: result }
    end

    def user_repos
      result = Github::GraphqlService.fetch_current_user_repositories(@current_user)
      render json: { data: result }
    end

    def update_repositories_data
      result = Github::GraphqlService.update_repositories_data
      render json: { data: result }
    end

    def add_repository
      repo_name = params[:repo_name]
      result = Github::GraphqlService.add_repo_by_name(repo_name)
      render json: { data: result }
    end

    def fetch_repo_updates
      repo_name = params[:repo_name]
      result = Github::GraphqlService.fetch_repository_update(repo_name)
      render json: { data: result }
    end

    def fetch_user_contributions
      result = Github::GraphqlService.fetch_user_contributions(@current_user)
      render json: { data: result }
    end

    def profile
      render json: { user: @current_user,
                     github_account: @current_user.github_account,
                     user_stat: @current_user.user_stat }
    end

    def update_profile
      allowed_params = profile_params

      if @current_user.update(allowed_params.slice(:email))
        if allowed_params[:token_usage_level].present?
          @current_user.update(token_usage_level: allowed_params[:token_usage_level])
        end

        render json: {
          user: @current_user,
          github_account: @current_user.github_account,
          user_stat: @current_user.user_stat
        }
      else
        render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(:email, :token_usage_level)
    end
  end
end
