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

  def user_prs
    result = Github::GraphqlService.fetch_current_user_prs(@current_user)
    render json: { data: result }
  end

  def user_issues
    result = Github::GraphqlService.fetch_current_user_issues(@current_user)
    render json: { data: result }
  end

  # GET /users
  def profile
    render json: { user: @current_user,
                   github_account: @current_user.github_account,
                   user_stat: @current_user.user_stat }
  end
end
