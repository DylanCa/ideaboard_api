class Issue < ApplicationRecord
  belongs_to :github_repository

  validates :github_id, presence: true, uniqueness: true
  validates :author_username, presence: true
  validates :title, presence: true
  validates :state, presence: true

  enum :state, { closed: 0, open: 1 }
end
