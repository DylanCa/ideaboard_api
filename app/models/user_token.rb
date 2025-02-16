class UserToken < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, presence: true
  validates :access_token, :refresh_token, :expires_at, presence: true
  validates :refresh_token, uniqueness: true

  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def expired?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end
end
