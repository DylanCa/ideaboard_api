class RepositoryUpdateWorker
  include Sidekiq::Job

  def perform(repo_name)
    repo = GithubRepository.find_by_full_name(repo_name)
    return nil if repo.nil?

    GithubRepositoryServices::OrchestrationService.fetch_repository_update(repo)
  end
end
