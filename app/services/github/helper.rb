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
          user_id = user_token&.user_id
          usage_type = :personal

          context[:token] = user_token.refresh!.user_token if user_token&.needs_refresh?
        end

        log_query_before_execution(query, variables, user_id)
        start_time = Time.current
        response = execute_query(query, variables, context)
        execution_time = calculate_execution_time(start_time)

        if response.errors.any?
          LoggerExtension.log(:error, "GraphQL Query Errors", {
            errors: response.errors,
            query: query.to_s
          })
          return nil
        end

        rate_limit_info = format_rate_limit_info(response.data.rate_limit)
        log_query_execution(response, execution_time, repo, usage_type, rate_limit_info)
        log_token_usage(user_id, repo, usage_type, query, variables, rate_limit_info)

        response
      rescue StandardError => e
        LoggerExtension.log(:error, "Unhandled GraphQL Error", {
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(10),
          query: query.to_s
        })
        nil
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

        cache_key = "token_for_repo_#{repo&.id || 'default'}"
        cached = Rails.cache.read(cache_key)
        return cached if cached

        result = detect_appropriate_token(repo)
        Rails.cache.write(cache_key, result, expires_in: 5.minutes)
        result
      end

      def detect_appropriate_token(repo)
        # First try: Repository owner's token
        owner = User.joins(:github_account)
                    .where(github_accounts: { github_username: repo.author_username })
                    .first

        if owner
          return get_return_values_with_refreshed_token(owner, :personal)
        end

        # Second try: Contributors tokens
        contributor_tokens = find_contributor_tokens(repo)
        if contributor_tokens.any?
          return get_return_values_with_refreshed_token(contributor_tokens.sample, :contributed)
        end

        # Last try: Global pool
        global_tokens = find_global_pool_tokens
        if global_tokens.any?
          return get_return_values_with_refreshed_token(global_tokens.sample, :global_pool)
        end

        # Fallback to app token
        [nil, installation_token, :global_pool]
      end

      def find_contributor_tokens(repo)
        User.where(token_usage_level: :contributed)
            .joins(:user_token, :user_repository_stats)
            .where("user_tokens.expires_at > ?", Time.current)
            .where(user_repository_stats: { github_repository_id: repo.id })
      end

      def find_global_pool_tokens
        User.where(token_usage_level: :global_pool)
            .joins(:user_token)
            .where("user_tokens.expires_at > ?", Time.current)
      end

      def get_return_values_with_refreshed_token(user, token_type)
        user.user_token.refresh!
        [user.id, user.access_token, token_type]
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

      def log_query_before_execution(query, variables, user_id)
        LoggerExtension.log(:info, "GraphQL Query Execution", {
          operation: query,
          variables: variables.inspect,
          token_owner_id: user_id
        })
      end

      def log_query_execution(response, execution_time, repo, usage_type, rate_limit_info)
        LoggerExtension.log(:info, "GraphQL Query Completed", {
          user: response.data.viewer.login,
          execution_time: "#{execution_time}ms",
          rate_limit: "#{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} requests remaining",
          usage_percentage: "#{rate_limit_info[:percentage_used]}%",
          repository: repo&.full_name,
          usage_type: usage_type
        })
        end

      def log_query_error(query, variables, response, error)
        query_error = response&.errors&.to_h || "undefined"

        LoggerExtension.log(:error, "GraphQL Query Error", {
          query_name: query.definition_name,
          variables: variables.inspect,
          error_message: error.message,
          query_error: query_error,
          backtrace: error.backtrace&.first(5)&.join("\n")
        })
      end
    end
  end
end
