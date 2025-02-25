class UserContributionsFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || user.github_account.nil?

    LoggerExtension.log(:info, "Starting User Contributions fetching.", {
      username: user.github_account.github_username,
      user_id: user_id,
      worker: "UserContributionsFetcherWorker"
    })

    items = { repositories: Set.new, prs: [], issues: [] }

    [ :prs, :issues ].each do |contrib_type|
      GithubRepositoryServices::QueryService.fetch_user_contribution_type(user.github_account.github_username, items, contrib_type, user.github_account.last_polled_at_date)
    end

    GithubRepositoryServices::ProcessingService.process_contributions(items)

    user.github_account.update(last_polled_at: Time.current)

    LoggerExtension.log(:info, "User Contributions fetching Completed", {
      username: user.github_account&.github_username,
      user_id: user_id,
      worker: "UserContributionsFetcherWorker"
    })
  end
end
