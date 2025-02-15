class PullRequest < ApplicationRecord
  belongs_to :github_repository

  validates :github_id, presence: true, uniqueness: true
  validates :author_username, presence: true
  validates :title, presence: true

  enum :state, { draft: 0, open: 1, closed: 2, merged: 3 }, prefix: true

  private

  def state
    # Convert GitHub's string state to our enum
    return state[:merged] if merged_at.present?
    return state[:closed] if closed_at.present?
    return state[:draft] if is_draft
    state[:open]
  end
end
