class GithubAccount < ApplicationRecord
  belongs_to :user

  validates :github_id, presence: true, uniqueness: true
  validates :github_username, presence: true, uniqueness: true
  validates :user_id, presence: true, uniqueness: true

  def last_polled_at_date
    return nil unless last_polled_at
    last_polled_at.strftime("%Y-%m-%dT%H:%M:%S+00:00")
  end
end
