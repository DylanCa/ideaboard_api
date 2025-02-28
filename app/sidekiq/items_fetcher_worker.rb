class ItemsFetcherWorker
  include BaseWorker

  def execute(repo_id, item_type = "both")
    repo = GithubRepository.find_by(id: repo_id)
    return nil if repo.nil?

    if item_type == "prs" || item_type == "both"
      prs = GithubRepositoryServices::QueryService.fetch_items(repo.full_name, item_type: :prs)
      GithubRepositoryServices::PersistenceService.update_repository_items(repo, prs, [])
    end

    if item_type == "issues" || item_type == "both"
      issues = GithubRepositoryServices::QueryService.fetch_items(repo.full_name, item_type: :issues)
      GithubRepositoryServices::PersistenceService.update_repository_items(repo, [], issues)
    end

    {
      repository_id: repo_id,
      full_name: repo.full_name,
      item_type: item_type,
      prs_count: item_type.include?("prs") ? prs&.size : 0,
      issues_count: item_type.include?("issues") ? issues&.size : 0
    }
  end
end