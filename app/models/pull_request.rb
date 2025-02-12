class PullRequest < ApplicationRecord
  belongs_to :github_repository
  has_one :issue, foreign_key: :closed_by_pull_request_id

  validates :full_database_id, presence: true, uniqueness: true
  validates :author_username, presence: true
  validates :title, presence: true
  validates :state, presence: true

  enum :state, { open: 0, closed: 1, merged: 2 }, prefix: true

  before_save :set_state_from_github

  private

  def set_state_from_github
    # Convert GitHub's string state to our enum
    self.state = if merged_at.present?
                   "merged"
    elsif state == "closed"
                   "closed"
    else
                   "open"
    end
  end
end
