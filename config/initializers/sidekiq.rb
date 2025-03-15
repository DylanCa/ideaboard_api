# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: "redis://redis:6379/0" }

  Sidekiq::Cron::Job.create(
    name: "Owner token repositories - tier 1",
    cron: "Every 1 hour",
    class: "RepositoryTierUpdateWorker",
    args: [ "owner_token" ]
  )

  Sidekiq::Cron::Job.create(
    name: "Contributor token repositories - tier 2",
    cron: "Every 6 hours",
    class: "RepositoryTierUpdateWorker",
    args: [ "contributor_token" ]
  )

  Sidekiq::Cron::Job.create(
    name: "Global pool repositories - tier 3",
    cron: "Every 12 hours",
    class: "RepositoryTierUpdateWorker",
    args: [ "global_pool" ]
  )

  Sidekiq::Cron::Job.create(
    name: "Process PR-Issue References",
    cron: "Every 1 hour",
    class: "ReferenceProcessorWorker"
  )
end
