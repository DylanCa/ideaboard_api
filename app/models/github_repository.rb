class GithubRepository < ApplicationRecord
  # Enums
  enum :update_method, { polling: 0, webhook: 1 }

  has_many :github_repository_topics, dependent: :destroy
  has_many :topics, through: :github_repository_topics
  has_many :issues, dependent: :destroy
  has_many :pull_requests, dependent: :destroy
  has_many :user_repository_stats, dependent: :destroy

  # Validations
  validates :full_name, :github_id, presence: true, uniqueness: true
  validates :stars_count, :forks_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :github_created_at, :github_updated_at, presence: true
  validates :is_fork, :archived, :disabled, :visible, :has_contributing,
            :app_installed, :webhook_installed, inclusion: { in: [ true, false ] }

  # Scopes
  scope :visible, -> { where(visible: true, archived: false, disabled: false) }
  scope :by_stars, -> { order(stars_count: :desc) }
  scope :active, -> { where(archived: false, disabled: false) }
  scope :with_language, ->(language) { where(language: language) }
  scope :recently_updated, -> { order(github_updated_at: :desc) }

  def last_polled_at_date
    return nil unless last_polled_at
    last_polled_at.strftime("%Y-%m-%dT%H:%M:%S+00:00")
  end
end
