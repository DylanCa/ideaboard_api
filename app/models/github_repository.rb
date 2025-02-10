class GithubRepository < ApplicationRecord
  belongs_to :project
  belongs_to :language
  has_many :github_repository_tags
  has_many :tags, through: :github_repository_tags
  has_many :issues
  has_many :pull_requests
end
