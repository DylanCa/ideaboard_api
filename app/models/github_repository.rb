class GithubRepository < ApplicationRecord
  belongs_to :project
  belongs_to :language
end
