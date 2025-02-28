module Github
  class RateLimitTrackingService
    class << self
      def extract_rate_limit_info(response)
        rate_limit = response.data.rate_limit
        {
          used: rate_limit.used,
          remaining: rate_limit.remaining,
          limit: rate_limit.limit,
          cost: rate_limit.cost,
          reset_at: rate_limit.reset_at,
          percentage_used: ((rate_limit.used.to_f / rate_limit.limit) * 100).round(2)
        }
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
    end
  end
end
