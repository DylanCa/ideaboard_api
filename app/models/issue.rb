class Issue < ApplicationRecord
  # Associations
  belongs_to :github_repository
  has_many :issue_labels, dependent: :destroy
  has_many :labels, through: :issue_labels

  # Validations
  validates :author_username, :title, :url, :number, presence: true
  validates :github_id, uniqueness: true, allow_nil: true
  validates :github_created_at, :github_updated_at, presence: true
  validates :number, uniqueness: { scope: :github_repository_id }

  # Scopes
  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :by_author, ->(username) { where(author_username: username) }
  scope :recent, -> { order(github_created_at: :desc) }


  STATE = { draft: 0, open: 1, closed: 2, merged: 3 }

  def state
    return STATE[:closed] if closed_at.present?
    STATE[:open]
  end
end
