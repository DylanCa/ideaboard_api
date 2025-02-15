class RateLimitLog < ApplicationRecord
  # Associations
  belongs_to :user, polymorphic: true

  # Validations
  validates :query_name, :cost, :remaining_points, :reset_at, :executed_at, presence: true
  validates :cost, :remaining_points, numericality: { greater_than_or_equal_to: 0 }
  validates :reset_at, comparison: { greater_than: :executed_at }

  # Scopes
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_owner, ->(owner) { where(token_owner: owner) }
  scope :by_query, ->(query_name) { where(query_name: query_name) }
  scope :costly, -> { where("cost > ?", 10) }
  scope :low_points_remaining, -> { where("remaining_points < ?", 1000) }
end
