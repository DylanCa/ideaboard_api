class RepositoryTierUpdateWorker
  include BaseWorker

  def execute(tier = "owner_token")
    repos = fetch_repositories_for_tier(tier)

    repos.each do |repo|
      RepositoryUpdateWorker.perform_async(repo.full_name)
    end

    { tier: tier, repos_updated_count: repos.count }
  end

  private

  def fetch_repositories_for_tier(tier)
    case tier
    when "owner_token"
      find_owner_token_repos
    when "contributor_token"
      find_contributor_token_repos
    when "global_pool"
      find_global_pool_repos
    else
      []
    end
  end

  def find_owner_token_repos
    GithubRepository.joins("INNER JOIN github_accounts ON github_repositories.author_username = github_accounts.github_username")
                    .joins("INNER JOIN user_tokens ON github_accounts.user_id = user_tokens.user_id")
                    .where("github_repositories.last_polled_at IS NULL OR github_repositories.last_polled_at < ?", 1.hour.ago)
  end

  def find_contributor_token_repos
    GithubRepository.joins(user_repository_stats: { user: :user_token })
                    .where(users: { token_usage_level: User.token_usage_levels[:contributed] })
                    .where("github_repositories.last_polled_at IS NULL OR github_repositories.last_polled_at < ?", 6.hours.ago)
                    .distinct
  end

  def find_global_pool_repos
    GithubRepository.where("last_polled_at IS NULL OR last_polled_at < ?", 12.hours.ago)
  end
end