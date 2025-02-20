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

  REFRESH_THRESHOLD = 1.hour

  def needs_refresh?
    expires_at - REFRESH_THRESHOLD <= Time.current
  end

  def refresh!
    return unless needs_refresh?

    new_tokens = Github::OauthService.refresh_token(refresh_token)

    update!(
      access_token: new_tokens[:access_token],
      refresh_token: new_tokens[:refresh_token],
      expires_at: Time.now.utc + new_tokens[:expires_in]
    )
  end
end
