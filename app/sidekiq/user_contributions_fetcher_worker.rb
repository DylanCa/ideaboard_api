class UserContributionsFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil?

    items = { repositories: Set.new, prs: [], issues: [] }

    [ :prs, :issues ].each do |contrib_type|
      GithubRepositoryServices::QueryService.fetch_user_contribution_type(user, items, contrib_type)
    end

    GithubRepositoryServices::ProcessingService.process_contributions(items)

    LoggerExtension.log(:info, "User Contributions Fetch Completed", {
      user: user.github_account&.github_username,
      action: "fetch_user_contributions"
    })
  end
end
