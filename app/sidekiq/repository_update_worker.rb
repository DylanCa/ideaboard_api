class RepositoryUpdateWorker
  include BaseWorker

  def execute(repo_name)
    repo = GithubRepository.find_by_full_name(repo_name)
    return nil if repo.nil?

    # Fetch repository data
    RepositoryFetcherWorker.new.perform(repo.full_name)

    # Fetch updates (PRs and issues)
    items = GithubRepositoryServices::QueryService.fetch_updates(repo.full_name, repo.last_polled_at_date)

    # Process the fetched items - THIS WAS MISSING
    GithubRepositoryServices::ProcessingService.process_contributions(items) if items.present?

    # Update last polled timestamp
    repo.update(last_polled_at: Time.current)

    # Return results summary
    {
      full_name: repo.full_name,
      updated: true,
      prs_count: items[:prs]&.count || 0,
      issues_count: items[:issues]&.count || 0
    }
  end
end
