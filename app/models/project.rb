class Project < ApplicationRecord
  belongs_to :user
  has_one :github_repository
  has_one :project_stat
end
