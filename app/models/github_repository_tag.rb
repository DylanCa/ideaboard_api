class GithubRepositoryTag < ApplicationRecord
  # Associations
  belongs_to :github_repository
  belongs_to :tag

  # Validations
  validates :github_repository_id, presence: true
  validates :tag_id, presence: true
  validates :github_repository_id, uniqueness: { scope: :tag_id }
end
