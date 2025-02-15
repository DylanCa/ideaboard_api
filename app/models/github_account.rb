class GithubAccount < ApplicationRecord
  belongs_to :user

  validates :github_id, presence: true, uniqueness: true
  validates :github_username, presence: true, uniqueness: true
  validates :user_id, presence: true, uniqueness: true
end
