class UserStat < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :reputation_points, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :top_contributors, -> { order(reputation_points: :desc) }
  scope :active_contributors, -> { where("reputation_points > 0") }
end
