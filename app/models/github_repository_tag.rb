class GithubRepositoryTag < ApplicationRecord
  belongs_to :github_repository
  belongs_to :tag
end
