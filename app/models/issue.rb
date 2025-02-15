class Issue < ApplicationRecord
  belongs_to :github_repository

  validates :github_id, presence: true, uniqueness: true
  validates :author_username, presence: true
  validates :title, presence: true
  validates :state, presence: true

  def state
    return 'closed' if closed_at.present?
    'open'
  end
end
