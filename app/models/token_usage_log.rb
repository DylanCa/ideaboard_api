class TokenUsageLog < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :github_repository, optional: true
  # Validations
  validates :usage_type, :points_used, :points_remaining, presence: true
  validates :points_used, :points_remaining, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :by_repository, ->(repo) { where(github_repository: repo) }
  scope :personal_queries, -> { where(usage_type: User.token_usage_levels[:personal]) }
  scope :contributed_queries, -> { where(usage_type: User.token_usage_levels[:contributed]) }
  scope :global_pool_queries, -> { where(usage_type: User.token_usage_levels[:global_pool]) }
end
