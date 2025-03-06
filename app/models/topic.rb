class Topic < ApplicationRecord
  # Associations
  has_many :github_repository_topics, dependent: :destroy
  has_many :github_repositories, through: :github_repository_topics

  # Validations
  validates :name, presence: true, uniqueness: true
end
