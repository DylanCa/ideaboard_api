class RepositoryUpdateWorker
  include BaseWorker

  def execute(repo_id)
    repo = GithubRepository.find_by(id: repo_id)
    return nil if repo.nil?

    RepositoryFetcherWorker.new.perform(repo.full_name)
    GithubRepositoryServices::QueryService.fetch_updates(repo.full_name, repo.last_polled_at_date)
    repo.update(last_polled_at: Time.current)

    { repository_id: repo_id, full_name: repo.full_name, updated: true }
  end
end