class UserToken < ApplicationRecord
  belongs_to :user

  validates :access_token, presence: true
  validates :refresh_token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end
end
