module Github
  class Helper
    class << self
      def query_with_logs(query, variables = nil, context = nil, repo_name = nil, username = nil)
        context ||= {}
        repo = GithubRepository.find_by_full_name(repo_name)

        if context[:token].nil?
          user_id, context[:token], usage_type = select_token(repo, username)
        else
          user_token = UserToken.find_by_access_token(context[:token])
          user_id = user_token.user_id
          usage_type = :personal

          context[:token] = user_token.refresh!.user_token if user_token.needs_refresh?
        end


        start_time = Time.current
        response = execute_query(query, variables, context)
        execution_time = calculate_execution_time(start_time)

        log_query_execution(query, variables, response, execution_time, user_id, repo, usage_type)
        response
      rescue => e
        log_query_error(query, variables, response, e)
        raise e
      end

      def installation_token
        return @token unless token_expired?

        # Get a new installation token
        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

        @token_expires_at = token_response[:expires_at]
        @token = token_response[:token]
      end

      private

      def select_token(repo, username)
        if username
          owner = User.joins(:github_account)
                      .where(github_accounts: { github_username: username })
                      .first

          unless owner.nil?
            owner.user_token.refresh!
            return [ owner.id, owner.access_token, :personal ]
          end
        end

        select_token_for_repository(repo)
      end

      def select_token_for_repository(repo)
        return [ nil, installation_token, :personal ] if repo.nil?

        # First try: Repository owner's token
        owner = User.joins(:github_account)
                    .where(github_accounts: { github_username: repo.author_username })
                    .first
        return [ owner.id, owner.access_token, :personal ] unless owner.nil?

        # Second try: Contributors tokens
        if (contributor_tokens = find_contributor_tokens(repo)).any?
          user_id, token = contributor_tokens.sample
          return [ user_id, token, :contributed ]
        end

        # Last try: Global pool
        if (global_tokens = find_global_pool_tokens).any?
          user_id, token = global_tokens.sample
          return [ user_id, token, :global_pool ]
        end

        # Fallback to app token
        [ nil, installation_token, :personal ]
      end

      def find_contributor_tokens(repo)
        User.where(token_usage_level: :contributed)
            .joins(:user_token, :user_repository_stats)
            .where("user_token.expires_at > ?", Time.current)
            .where(user_repository_stats: { github_repository_id: repo.id })
            .pluck(:id, "user_token.access_token")
            .map { |id, token| [ id, token ] }
      end

      def find_global_pool_tokens
        User.where(token_usage_level: :global_pool)
            .joins(:user_token)
            .where("user_token.expires_at > ?", Time.current)
            .pluck(:id, "user_token.access_token")
            .map { |id, token| [ id, token ] }
      end

      def log_token_usage(user_id, repo, usage_type, query, variables, rate_limit_info)
        TokenUsageLog.create!(
          user_id: user_id,
          github_repository: repo,
          query: query,
          variables: variables,
          usage_type: User.token_usage_levels[usage_type],
          points_used: rate_limit_info[:cost],
          points_remaining: rate_limit_info[:remaining]
        )
      end

      def execute_query(query, variables, context)
        args = { variables: variables, context: context }.compact
        args.empty? ? Github.client.query(query) : Github.client.query(query, **args)
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
        @token_expires_at - 5.minutes < Time.current
      end

      def calculate_execution_time(start_time)
        ((Time.current - start_time) * 1000).round(2)
      end

      def format_rate_limit_info(rate_limit)
        {
          used: rate_limit.used,
          remaining: rate_limit.remaining,
          limit: rate_limit.limit,
          cost: rate_limit.cost,
          reset_at: rate_limit.reset_at,
          percentage_used: ((rate_limit.used.to_f / rate_limit.limit) * 100).round(2)
        }
      end

      def log_query_execution(query, variables, response, execution_time, user_id, repo, usage_type)
        rate_limit_info = format_rate_limit_info(response.data.rate_limit)

        log_token_usage(user_id, repo, usage_type, query, variables, rate_limit_info)

        Rails.logger.info do
          <<~LOG
      \e[36m[GraphQL Query]\e[0m #{execution_time}ms
      \e[34mUser:\e[0m #{response.data.viewer.login}
      \e[34mOperation:\e[0m #{query}
      \e[34mVariables:\e[0m #{variables.inspect}
      \e[35m[Rate Limit]\e[0m Cost: #{rate_limit_info[:cost]} points | \e[32m#{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]}\e[0m requests remaining (#{rate_limit_info[:percentage_used]}% used) | Resets at: #{rate_limit_info[:reset_at]}
      \e[33m[Response]\e[0m
      #{response.data.to_h}
    LOG
        end
      end

      def log_query_error(query, variables, response, error)
        query_error = response.errors&.to_h
        Rails.logger.error do
          <<~ERROR
      \e[31m[GraphQL Error]\e[0m
      Query: #{query.definition_name}
      Variables: #{variables.inspect}
      Error: #{error.message}
      Query Error: #{query_error}
      #{error.backtrace.first(5).join("\n")}
    ERROR
        end
      end
    end
  end
end
