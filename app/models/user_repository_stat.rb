class UserRepositoryStat < ApplicationRecord
  belongs_to :user
  belongs_to :github_repository

  validates :user_id, uniqueness: { scope: :github_repository_id }
  validates :opened_prs_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :merged_prs_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :issues_opened_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :issues_closed_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :issues_with_pr_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
