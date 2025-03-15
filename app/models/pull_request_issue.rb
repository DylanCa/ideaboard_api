class PullRequestIssue < ApplicationRecord
  # Validations
  validates :pr_repository, :pr_number, :issue_repository, :issue_number, presence: true
  validates :pr_number, uniqueness: { scope: [ :pr_repository, :issue_repository, :issue_number ] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :unprocessed, -> { where(processed_at: nil) }

  # Relationships (optional - these help link to actual objects if they exist)
  def pull_request
    PullRequest.joins(:github_repository)
               .where(github_repositories: { full_name: pr_repository }, number: pr_number)
               .first
  end

  def issue
    Issue.joins(:github_repository)
         .where(github_repositories: { full_name: issue_repository }, number: issue_number)
         .first
  end
end
