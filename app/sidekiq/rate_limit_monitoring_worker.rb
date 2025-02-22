class RateLimitMonitoringWorker
  include Sidekiq::Job

  sidekiq_options queue: :low_priority, retry: 3

  def perform
    low_limit_tokens = RateLimitLog
                         .where("created_at > ?", 1.hour.ago)
                         .where("remaining_points < 1000")
                         .group(:token_owner_type, :token_owner_id)
                         .count

    if low_limit_tokens.any?
      LoggerExtension.log(:warn, "Low Rate Limit Detected", {
        tokens_count: low_limit_tokens.size,
        action: "rate_limit_monitoring"
      })

      # Alert or take action based on rate limit status
    end
  end
end
