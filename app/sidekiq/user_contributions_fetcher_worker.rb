class UserContributionsFetcherWorker
  include BaseWorker

  def execute(user_id)
    user = User.find_by(id: user_id)
    return nil if user.nil? || user.github_account.nil?

    items = { repositories: Set.new, prs: [], issues: [] }

    fetch_newly_created_repos(user)
    fetch_newly_updated_contributions(user, items)

    user.github_account.update(last_polled_at: Time.current)

    UserRepositoryStatWorker.perform_async(user.id)

    {
      username: user.github_account.github_username,
      repos_count: items[:repositories].size,
      prs_count: items[:prs].count,
      issues_count: items[:issues].count
    }
  end

  private

  def fetch_newly_created_repos(user)
    repos_result = GithubRepositoryServices::QueryService.fetch_user_repos(
      user.github_account.github_username,
      user.github_account.last_polled_at_date
    )

    if repos_result && repos_result[0]
      Persistence::RepositoryPersistenceService.persist_many(repos_result[0])
    end
  end

  def fetch_newly_updated_contributions(user, items)
    [ :prs, :issues ].each do |contrib_type|
      GithubRepositoryServices::QueryService.fetch_user_contributions(
        user.github_account.github_username,
        items,
        contrib_type,
        user.github_account.last_polled_at_date
      )
    end

    GithubRepositoryServices::ProcessingService.process_contributions(items)
  end
end
