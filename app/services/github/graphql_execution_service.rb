module Github
  class GraphQLExecutionService
    class << self
      def execute_query(query, variables = nil, context = nil, repo_name = nil, username = nil)
        context ||= {}
        repo = GithubRepository.find_by_full_name(repo_name)

        # Get token if not provided
        if context[:token].nil?
          user_id, context[:token], usage_type = TokenSelectionService.select_token(repo, username)
        else
          user_token = UserToken.find_by_access_token(context[:token])
          user_id = user_token&.user_id
          usage_type = :personal
        end

        # Log before execution
        log_query_before_execution(query, variables, user_id)

        # Execute query with timing
        start_time = Time.current
        response = perform_query_execution(query, variables, context)
        execution_time = calculate_execution_time(start_time)

        # Handle response and logging
        if response.errors&.any?
          LoggerExtension.log(:error, "GraphQL Query Errors", {
            errors: response.errors,
            query: query.to_s
          })

          nil
        else
          rate_limit_info = RateLimitTrackingService.extract_rate_limit_info(response)

          # Log execution details
          log_query_execution(response, execution_time, repo, usage_type, rate_limit_info)

          # Track rate limit usage
          RateLimitTrackingService.log_token_usage(
            user_id, repo, usage_type, query, variables, rate_limit_info
          )

          response
        end
      rescue StandardError => e
        LoggerExtension.log(:error, "Unhandled GraphQL Error", {
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(10),
          query: query.to_s
        })
        nil
      end

      private

      def perform_query_execution(query, variables, context)
        args = { variables: variables, context: context }.compact
        response = args.empty? ? Github.client.query(query) : Github.client.query(query, **args)
        return response unless response.errors&.any?

        LoggerExtension.log(:error, "GraphQL Query Errors", {
          errors: response.errors,
          query: query.to_s
        })

        nil
      end

      def calculate_execution_time(start_time)
        ((Time.current - start_time) * 1000).round(2)
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
    end
  end
end
