class UserToken < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, :access_token, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
end
