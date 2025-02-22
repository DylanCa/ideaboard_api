Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }

  # Schedule recurring jobs
  Sidekiq::Cron::Job.create(
    name: "Repository polling every hour",
    cron: "0 * * * *",
    class: "BatchRepositoryPollingWorker"
  )

  Sidekiq::Cron::Job.create(
    name: "Rate limit monitoring every 15 minutes",
    cron: "*/15 * * * *",
    class: "RateLimitMonitoringWorker"
  )
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }
end
