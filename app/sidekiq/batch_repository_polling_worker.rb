class BatchRepositoryPollingWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform
    # Find repositories that need to be polled
    repos = GithubRepository.needs_polling.limit(50)

    repos.each do |repo|
      # Schedule individual updates with some delay to avoid overwhelming the API
      RepositoryUpdateOrchestrationWorker.perform_in(rand(1..5).minutes, repo.id)
    end
  end
end
