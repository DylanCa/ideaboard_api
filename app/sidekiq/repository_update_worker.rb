class RepositoryUpdateWorker
  include BaseWorker

  def execute(repo_name)
    repo = GithubRepository.find_by_full_name(repo_name)
    return nil if repo.nil?

    RepositoryFetcherWorker.new.perform(repo.full_name)
    items = GithubRepositoryServices::QueryService.fetch_updates(repo.full_name, repo.last_polled_at_date)
    GithubRepositoryServices::ProcessingService.process_contributions(items) if items.present?

    repo.update(last_polled_at: Time.current)

    {
      full_name: repo.full_name,
      updated: true,
      prs_count: items[:prs]&.count || 0,
      issues_count: items[:issues]&.count || 0
    }
  end
end
