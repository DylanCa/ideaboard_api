module JwtAuthenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token
    payload = JwtService.decode(token)
    @current_user = User.joins(:github_account)
                        .find_by!(id: payload['user_id'],
                                  github_accounts: { github_username: payload['github_username'] })
  rescue StandardError => e
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def extract_token
    authorization_header = request.headers['Authorization']
    authorization_header.split(' ').last if authorization_header
  end
end
