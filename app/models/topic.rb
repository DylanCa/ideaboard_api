class Topic < ApplicationRecord
  # Associations
  has_many :github_repository_topics, dependent: :destroy
  has_many :github_repositories, through: :github_repository_topics

  # Validations
  validates :name, presence: true, uniqueness: true

  # Scopes
  scope :popular, -> {
    joins(:github_repository_topics)
      .group(:id)
      .order("COUNT(github_repository_topics.id) DESC")
  }
end
