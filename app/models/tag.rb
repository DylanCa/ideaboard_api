class Tag < ApplicationRecord
  # Associations
  has_many :github_repository_tags, dependent: :destroy
  has_many :github_repositories, through: :github_repository_tags

  # Validations
  validates :name, presence: true, uniqueness: true

  # Scopes
  scope :popular, -> {
    joins(:github_repository_tags)
      .group(:id)
      .order('COUNT(github_repository_tags.id) DESC')
  }
end