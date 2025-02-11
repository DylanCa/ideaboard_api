class UsersController < ApplicationController
  include JwtAuthenticable

  # GET /users
  def profile
    render json: { user: @current_user,
                   github_account: @current_user.github_account,
                   user_stat: @current_user.user_stat }
  end

  def repo_prs
    repo_name = params[:repo_name]
    client = Github::UserClientService.new(@current_user)
    repo = client.get_repo_prs(repo_name)
    render json: repo
  end

  def repos
    client = Github::UserClientService.new(@current_user)
    repos = client.public_repositories
    render json: repos
  end

  def issues
    client = Github::UserClientService.new(@current_user)
    repos = client.issues
    render json: repos
  end

  def prs
    client = Github::UserClientService.new(@current_user)
    repos = client.pull_requests
    render json: repos
  end
end
