class UsersController < ApplicationController
  include JwtAuthenticable

  # GET /users
  def profile
    render json: { user: @current_user,
                   github_account: @current_user.github_account,
                   user_stat: @current_user.user_stat }
  end
end
