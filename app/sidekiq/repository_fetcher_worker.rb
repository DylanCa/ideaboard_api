class RepositoryFetcherWorker
  include BaseWorker

  def execute(repo_name)
    repo = GithubRepositoryServices::QueryService.fetch_repository(repo_name)
    return if repo.nil?

    Persistence::RepositoryPersistenceService.persist_many([ repo ])[0]
  end
end
