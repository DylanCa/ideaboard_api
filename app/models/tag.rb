class Tag < ApplicationRecord
  has_many :github_repository_tags
  has_many :github_repositories, through: :github_repository_tags
end
