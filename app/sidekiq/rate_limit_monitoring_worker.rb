class RateLimitMonitoringWorker
  include BaseWorker
  sidekiq_options queue: :low_priority

  def execute
    low_limit_tokens = RateLimitLog
                         .where("created_at > ?", 1.hour.ago)
                         .where("remaining_points < 1000")
                         .group(:token_owner_type, :token_owner_id)
                         .count

    if low_limit_tokens.any?
      {
        low_limit_tokens_count: low_limit_tokens.size,
        tokens: low_limit_tokens.keys
      }
    else
      { status: "ok", low_limit_tokens_count: 0 }
    end
  end
end
