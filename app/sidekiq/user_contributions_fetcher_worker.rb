class UserContributionsFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || user.github_account.nil?

    LoggerExtension.log(:info, "Starting User Contributions & Repos fetching.", {
      username: user.github_account.github_username,
      user_id: user_id,
      worker: "UserContributionsFetcherWorker"
    })

    items = { repositories: Set.new, prs: [], issues: [] }

    fetch_newly_created_repos(user)
    fetch_newly_updated_contributions(user, items)

    user.github_account.update(last_polled_at: Time.current)

    UserRepositoryStatWorker.perform_async(user.id)

    LoggerExtension.log(:info, "User Contributions & Repos fetching Completed", {
      username: user.github_account&.github_username,
      user_id: user_id,
      worker: "UserContributionsFetcherWorker"
    })
  end

  private

  def fetch_newly_created_repos(user)
    repos = GithubRepositoryServices::QueryService.fetch_user_repos(user.github_account.github_username, user.github_account.last_polled_at_date)[0]
    return if repos.nil?

    Persistence::RepositoryPersistenceService.persist_many(repos)

    LoggerExtension.log(:info, "Persisted #{repos.count} repos.", {
      username: user.github_account.github_username,
      user_id: user.id,
      worker: "UserContributionsFetcherWorker"
    })
  end

  def fetch_newly_updated_contributions(user, items)
    [ :prs, :issues ].each do |contrib_type|
      GithubRepositoryServices::QueryService.fetch_user_contributions(user.github_account.github_username, items, contrib_type, user.github_account.last_polled_at_date)
    end

    GithubRepositoryServices::ProcessingService.process_contributions(items)
    LoggerExtension.log(:info, "Persisted #{items[:prs].count} prs & #{items[:issues].count} issues.", {
      username: user.github_account.github_username,
      user_id: user.id,
      worker: "UserContributionsFetcherWorker"
    })
  end
end
