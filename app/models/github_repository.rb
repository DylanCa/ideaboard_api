class GithubRepository < ApplicationRecord
  has_many :issues
  has_many :pull_requests
  has_many :github_repository_tags
  has_many :tags, through: :github_repository_tags
  has_many :user_repository_stats
  has_many :contributors, through: :user_repository_stats, source: :user

  def last_synced_at_date
    return nil unless last_synced_at
    last_synced_at.strftime("%Y-%m-%d")
  end
end
