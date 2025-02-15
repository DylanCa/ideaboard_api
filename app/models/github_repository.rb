class GithubRepository < ApplicationRecord
  # Enums
  enum :update_method, { polling: 0, webhook: 1 }

  # Associations
  belongs_to :owner, class_name: "User", optional: true
  has_many :github_repository_tags, dependent: :destroy
  has_many :tags, through: :github_repository_tags
  has_many :issues, dependent: :destroy
  has_many :pull_requests, dependent: :destroy
  has_many :user_repository_stats, dependent: :destroy

  # Validations
  validates :full_name, presence: true, uniqueness: true
  validates :github_id, uniqueness: true, allow_nil: true
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
  scope :needs_polling, -> { where(update_method: :polling).where("last_polled_at < ?", 1.hour.ago) }

  def last_polled_at_date
    return nil unless last_polled_at
    last_polled_at.strftime("%Y-%m-%d")
  end
end
