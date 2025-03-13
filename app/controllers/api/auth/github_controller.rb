module Api
  module Auth
    class GithubController < ApplicationController
      include Api::Concerns::JwtAuthenticable
      skip_before_action :authenticate_user!

      def initiate
        # Generate state parameter for security
        state = SecureRandom.hex(24)

        # Store state in session or cache to verify on callback
        session_store = Rails.cache.write("oauth_state:#{state}", { created_at: Time.current }, expires_in: 10.minutes)

        # Construct GitHub OAuth URL
        github_url = "https://github.com/login/oauth/authorize"
        params = {
          client_id: ENV["GITHUB_APP_CLIENT_ID"],
          redirect_uri: api_auth_github_callback_url,
          scope: "user:email,read:user,repo",
          state: state
        }

        redirect_url = "#{github_url}?#{params.to_query}"
        render_success({ redirect_url: redirect_url }, {}, :ok)
      end

      def callback
        code = params[:code]
        state = params[:state]

        # Verify state if it was sent
        if state.present?
          stored_state = Rails.cache.read("oauth_state:#{state}")
          if stored_state.nil?
            return render_error("Invalid OAuth state", :unauthorized)
          end
          Rails.cache.delete("oauth_state:#{state}")
        end

        res = Github::OauthService.authenticate(code)

        if res[:is_authenticated]
          user = res[:user]

          payload = {
            user_id: user.id,
            github_username: user.github_account.github_username,
            iat: Time.now.to_i
          }

          jwt_token = JwtService.encode(payload)
          render json: { jwt_token: jwt_token,
                         user: user,
                         github_account: user.github_account,
                         user_stat: user.user_stat }
        else
          render_error("Authentication failed", :unauthorized)
        end
      end
    end
  end
end
