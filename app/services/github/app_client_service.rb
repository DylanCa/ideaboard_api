module Github
  class AppClientService
    class << self
      def installation_token
        return @token unless token_expired?

        # Get a new installation token
        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

        # The expires_at might already be a Time object
        @token_expires_at = token_response[:expires_at]
        @token = token_response[:token]
      end

      def jwt
        private_key = OpenSSL::PKey::RSA.new(ENV["GITHUB_APP_PRIVATE_KEY"])
        payload = {
          iat: Time.now.to_i - 60,
          exp: Time.now.to_i + (10 * 60),
          iss: ENV["GITHUB_APP_CLIENT_ID"]
        }

        JWT.encode(payload, private_key, "RS256")
      end

      def token_expired?
        return true if @token_expires_at.nil?
        # Add some buffer (say 5 minutes) to ensure we refresh before actual expiration
        @token_expires_at - 5.minutes < Time.current
      end
    end
  end
end
