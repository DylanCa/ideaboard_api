class UserRepositoriesFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find(user_id)

    LoggerExtension.log(:info, "Starting User Repos fetching.", {
      username: user.github_account.github_username,
      user_id: user_id,
      worker: "UserRepositoriesFetcherWorker"
    })

    response = Github::Helper.query_with_logs(Queries::UserQueries.user_repositories, nil, { token: user.access_token })
    repos = response.data&.viewer&.repositories&.nodes
    return if repos.nil?

    Persistence::RepositoryPersistenceService.persist_many(repos, user.id)

    LoggerExtension.log(:info, "User Repos fetching Completed", {
      repos_count: repos.count,
      username: user.github_account&.github_username,
      user_id: user_id,
      worker: "UserRepositoriesFetcherWorker"
    })
  end
end
