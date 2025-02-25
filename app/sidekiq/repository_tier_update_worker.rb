class RepositoryTierUpdateWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(tier = :owner_token)
    LoggerExtension.log(:info, "Starting repository update.", { tier: tier, worker: "RepositoryTierUpdateWorker" })


    repos = case tier
    when "owner_token"
              find_owner_token_repos
    when "contributor_token"
              find_contributor_token_repos
    when "global_pool"
              find_global_pool_repos
    end

    repos.each do |repo|
      RepositoryUpdateWorker.perform_async(repo.id)
    end

    LoggerExtension.log(:info, "Repository update completed.", { tier: tier, repos_updated_count: repos.count, worker: "RepositoryTierUpdateWorker" })
  end

  private

  def find_owner_token_repos
    GithubRepository.joins(owner: :user_token)
                            .where("user_tokens.expires_at > ?", Time.current)
                            .where("last_polled_at IS NULL OR last_polled_at < ?", 1.hour.ago)
  end

  def find_contributor_token_repos
    GithubRepository.joins(user_repository_stats: { user: :user_token })
                    .where("user_tokens.expires_at > ?", Time.current)
                    .where(users: { token_usage_level: User.token_usage_levels[:contributed] })
                    .where(owner_id: nil)
                    .where("last_polled_at IS NULL OR last_polled_at < ?", 6.hours.ago)
                    .distinct
  end

  def find_global_pool_repos
    GithubRepository.where("owner_id IS NULL")
                    .where("last_polled_at IS NULL OR last_polled_at < ?", 12.hours.ago)
  end
end
