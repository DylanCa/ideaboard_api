class Issue < ApplicationRecord
  belongs_to :github_repository
  belongs_to :closing_pull_request, class_name: "PullRequest",
             foreign_key: :closed_by_pull_request_id,
             optional: true

  validates :github_id, presence: true, uniqueness: true
  validates :github_username, presence: true
  validates :title, presence: true
  validates :state, presence: true
  validates :reaction_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  enum :state, { closed: 0, open: 1 }
end
