module Github
  class AppClientService
    class << self
      def client
        # Return cached client if installation token is still valid
        return @client if @client && !token_expired?

        # Otherwise create new client with fresh token
        @client = Octokit::Client.new(access_token: installation_token)
      end

      private

      def installation_token
        # Get a new installation token
        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

        # Cache token and its expiration
        @token_expires_at = Time.parse(token_response[:expires_at])
        token_response[:token]
      end

      def jwt
        private_key = OpenSSL::PKey::RSA.new(ENV['GITHUB_APP_PRIVATE_KEY'])
        payload = {
          iat: Time.now.to_i - 60,
          exp: Time.now.to_i + (10 * 60),
          iss: ENV['GITHUB_APP_CLIENT_ID']
        }

        JWT.encode(payload, private_key, 'RS256')
      end

      def token_expired?
        return true if @token_expires_at.nil?
        # Add some buffer (say 5 minutes) to ensure we refresh before actual expiration
        @token_expires_at - 5.minutes < Time.current
      end
    end
  end
end
