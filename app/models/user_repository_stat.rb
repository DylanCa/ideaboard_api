class UserRepositoryStat < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :github_repository

  # Validations
  validates :user_id, uniqueness: { scope: :github_repository_id }
  validates :opened_prs_count, :merged_prs_count, :issues_opened_count,
            :issues_closed_count, :issues_with_pr_count,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :with_contributions, -> {
    where('opened_prs_count > 0 OR issues_opened_count > 0')
  }
  scope :with_merged_prs, -> { where('merged_prs_count > 0') }
  scope :by_contribution_count, -> {
    order('merged_prs_count + issues_closed_count DESC')
  }
end