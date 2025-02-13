require_relative '../services/persistence/repository_data_service'

class UsersController < ApplicationController
  include JwtAuthenticable
  def user_contributions
    result = Services::Persistence::RepositoryProcessor.update_all_repositories
    render json: { data: result }
  end

  # GET /users
  def profile
    render json: { user: @current_user,
                   github_account: @current_user.github_account,
                   user_stat: @current_user.user_stat }
  end
end
