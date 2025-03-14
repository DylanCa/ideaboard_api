class UserRepositoriesFetcherWorker
  include BaseWorker

  def execute(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || user.github_account.nil?

    response = Github::Helper.query_with_logs(
      Queries::UserQueries.user_repositories,
      nil,
      { token: user.access_token }
    )

    repos = response.data&.viewer&.repositories&.nodes
    return if repos.nil?

    Persistence::RepositoryPersistenceService.persist_many(repos)

    { repos_count: repos.count, username: user.github_account.github_username }
  end
end
