class UsersController < ApplicationController
  include JwtAuthenticable

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
    result = Github::GraphqlService.fetch_repo_by_name(repo_name)
    render json: { data: result }
  end

  # GET /users
  def profile
    render json: { user: @current_user,
                   github_account: @current_user.github_account,
                   user_stat: @current_user.user_stat }
  end
end
