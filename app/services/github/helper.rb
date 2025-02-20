module Github
  class Helper
    class << self
      def query_with_logs(query, variables = nil, context = nil)
        start_time = Time.current
        response = execute_query(query, variables, context)
        execution_time = calculate_execution_time(start_time)

        log_query_execution(query, variables, response, execution_time)
        response
      rescue => e
        log_query_error(query, variables, e)
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

      def log_query_execution(query, variables, response, execution_time)
        rate_limit_info = format_rate_limit_info(response.data.rate_limit)

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

      def log_query_error(query, variables, error)
        Rails.logger.error do
          <<~ERROR
      \e[31m[GraphQL Error]\e[0m
      Query: #{query.definition_name}
      Variables: #{variables.inspect}
      Error: #{error.message}
      #{error.backtrace.first(5).join("\n")}
    ERROR
        end
      end
    end
  end
end