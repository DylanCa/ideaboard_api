class User < ApplicationRecord
  # Associations
  has_one :github_account, dependent: :destroy
  has_one :user_stat, dependent: :destroy
  has_many :user_tokens, dependent: :destroy
  has_many :owned_repositories, class_name: "GithubRepository", foreign_key: "owner_id", dependent: :nullify
  has_many :user_repository_stats, dependent: :destroy
  has_many :rate_limit_logs, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :account_status, presence: true
  validates :allow_token_usage, inclusion: { in: [ true, false ] }

  accepts_nested_attributes_for :github_account
  accepts_nested_attributes_for :user_tokens
  accepts_nested_attributes_for :user_stat

  enum :account_status, { enabled: 1, disabled: 0, banned: -1 }

  enum :token_usage_level, {
    no_usage: 0,        # Default - no token usage
    personal_only: 1,   # Only their data
    contributed: 2,     # Their data + repos they contributed to
    global_pool: 3      # Any repository
  }, default: 0

  scope :with_github_id, ->(github_id) {
    joins(:github_account).where(github_account: { github_id: github_id })
  }

  def access_token
    last_token = user_tokens.last
    return last_token.access_token if last_token.expires_at > Time.now.utc

    # TODO: Implement refresh token logic here
    raise Octokit::Error
  end

  def issues
    Issue.where(author_username: github_account.github_username).order(:created_at)
  end

  def pull_requests
    PullRequest.where(author_username: github_account.github_username).order(:created_at)
  end

  def repositories
    GithubRepository.where(author_username: github_account.github_username).order(:created_at)
  end
end
