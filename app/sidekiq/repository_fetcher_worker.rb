class RepositoryFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(repo_name)
    repo = GithubRepositoryServices::QueryService.fetch_repository(repo_name)
    return if repo.nil?

    inserted_repo = Persistence::RepositoryPersistenceService.persist_many([ repo ])[0]

    LoggerExtension.log(:info, "Repository Fetch Completed", {
      repository: repo_name,
      action: "fetch_repository"
    })

    inserted_repo
  end
end
