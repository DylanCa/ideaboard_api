module Github
  class TokenSelectionService
    class << self
      def select_token(repo = nil, username = nil)
        if username
          owner = User.joins(:github_account)
                      .where(github_accounts: { github_username: username })
                      .first

          unless owner.nil?
            return [ owner.id, owner.access_token, :personal ]
          end
        end

        select_token_for_repository(repo)
      end

      def select_token_for_repository(repo)
        return [ nil, installation_token, :global_pool ] if repo.nil?

        cache_key = "token_for_repo_#{repo&.id || 'default'}"
        cached = Rails.cache.read(cache_key)
        return cached if cached

        result = detect_appropriate_token(repo)
        Rails.cache.write(cache_key, result, expires_in: 5.minutes)
        result
      end

      def installation_token
        return @token unless @token.nil?

        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

        @token = token_response[:token]
      end

      private

      def detect_appropriate_token(repo)
        # First try: Repository owner's token
        owner = User.joins(:github_account)
                    .where(github_accounts: { github_username: repo.author_username })
                    .first

        return [ owner.id, owner.access_token, :personal ] if owner

        # Second try: Contributors tokens
        contributor_tokens = find_contributor_tokens(repo)
        if contributor_tokens.any?
          id, token = contributor_tokens.sample
          return [ id, token, :contributed ]
        end

        # Last try: Global pool
        global_tokens = find_global_pool_tokens
        if global_tokens.any?
          id, token = global_tokens.sample
          return [ id, token, :global_pool ]
        end

        # Fallback to app token
        [ nil, installation_token, :global_pool ]
      end

      def find_contributor_tokens(repo)
        User.where(token_usage_level: :contributed)
            .joins(:user_token, :user_repository_stats)
            .where(user_repository_stats: { github_repository_id: repo.id })
          .pluck([ :id, :access_token ])
      end

      def find_global_pool_tokens
        User.where(token_usage_level: :global_pool)
            .joins(:user_token)
          .pluck([ :id, :access_token ])
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
    end
  end
end
