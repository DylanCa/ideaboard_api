class PullRequest < ApplicationRecord
  belongs_to :github_repository
end
