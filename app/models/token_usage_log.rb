class TokenUsageLog < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :github_repository, optional: true
  # Validations
  validates :usage_type, :points_used, :points_remaining, presence: true
  validates :points_used, :points_remaining, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_repository, ->(repo) { where(github_repository: repo) }
  scope :installation_queries, -> { where(usage_type: :installation) }
  scope :user_queries, -> { where.not(usage_type: :installation) }
end
