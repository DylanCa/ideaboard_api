class GithubRepositoryTopic < ApplicationRecord
  # Associations
  belongs_to :github_repository
  belongs_to :topic

  # Validations
  validates :github_repository_id, presence: true
  validates :topic_id, presence: true
  validates :github_repository_id, uniqueness: { scope: :topic_id }
end
