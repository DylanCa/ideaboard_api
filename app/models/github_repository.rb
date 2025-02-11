class GithubRepository < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :language

  has_many :issues
  has_many :pull_requests
  has_many :github_repository_tags
  has_many :tags, through: :github_repository_tags
  has_many :user_repository_stats
  has_many :contributors, through: :user_repository_stats, source: :user
end
