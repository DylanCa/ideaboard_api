class PullRequest < ApplicationRecord
  belongs_to :github_repository
  has_one :issue, foreign_key: :closed_by_pull_request_id

  validates :github_id, presence: true, uniqueness: true
  validates :github_username, presence: true
  validates :title, presence: true
  validates :state, presence: true

  enum state: { open: 0, closed: 1, merged: 2 }
end
