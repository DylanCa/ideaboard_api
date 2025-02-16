class PullRequest < ApplicationRecord
  # Associations
  belongs_to :github_repository
  has_many :pull_request_labels, dependent: :destroy
  has_many :labels, through: :pull_request_labels

  # Validations
  validates :author_username, :title, :url, :number, presence: true
  validates :github_id, uniqueness: true, allow_nil: true
  validates :github_created_at, :github_updated_at, presence: true
  validates :number, uniqueness: { scope: :github_repository_id }
  validates :is_draft, inclusion: { in: [ true, false ] }

  # Scopes
  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :merged, -> { where.not(merged_at: nil) }
  scope :not_merged, -> { where(merged_at: nil) }
  scope :by_author, ->(username) { where(author_username: username) }
  scope :not_draft, -> { where(is_draft: false) }
  scope :recent, -> { order(github_created_at: :desc) }


  STATE = { draft: 0, open: 1, closed: 2, merged: 3 }

  def state
    return STATE[:merged] if merged_at.present?
    return STATE[:closed] if closed_at.present?
    return STATE[:draft] if is_draft
    STATE[:open]
  end
end
