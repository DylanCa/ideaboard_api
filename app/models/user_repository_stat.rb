class UserRepositoryStat < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :github_repository

  # Validations
  validates :user_id, uniqueness: { scope: :github_repository_id }
  validates :opened_prs_count, :merged_prs_count, :issues_opened_count,
            :issues_closed_count, :issues_with_pr_count,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
end
