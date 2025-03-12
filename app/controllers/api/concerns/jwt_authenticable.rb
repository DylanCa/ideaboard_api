module Api
  module Concerns
  module JwtAuthenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def current_user
    @current_user
  end

  def update_profile
    # Only allow updating specific fields
    allowed_params = profile_params

    # Update user record
    if @current_user.update(allowed_params.slice(:email))
      # If token usage level is being updated
      if allowed_params[:token_usage_level].present?
        @current_user.update(token_usage_level: allowed_params[:token_usage_level])
      end

      # Return updated profile
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

  def authenticate_user!
    token = extract_token
    payload = JwtService.decode(token)
    @current_user = User.joins(:github_account)
                        .find_by!(id: payload["user_id"],
                                  github_accounts: { github_username: payload["github_username"] })
  rescue StandardError => e
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def extract_token
    authorization_header = request.headers["Authorization"]
    authorization_header.split(" ").last if authorization_header
  end

  def profile_params
    params.require(:user).permit(:email, :token_usage_level)
  end
  end
  end
end
