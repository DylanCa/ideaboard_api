class ItemsFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(repo_id, item_type = "both", update_last_polled_at = false)
    repo = GithubRepository.find_by(id: repo_id)
    return if repo.nil?

    if item_type == "prs" || item_type == "both"
      prs = GithubRepositoryServices::QueryService.fetch_items(repo.full_name, item_type: :prs)
      GithubRepositoryServices::PersistenceService.update_repository_items(repo, prs, [])
    end

    if item_type == "issues" || item_type == "both"
      issues = GithubRepositoryServices::QueryService.fetch_items(repo.full_name, item_type: :issues)
      GithubRepositoryServices::PersistenceService.update_repository_items(repo, [], issues)
    end

    repo.update(last_polled_at: Time.current) if update_last_polled_at

    LoggerExtension.log(:info, "Items Fetch Completed", {
      repository: repo.full_name,
      item_type: item_type,
      action: "fetch_items"
    })
  end
end
