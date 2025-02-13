class User < ApplicationRecord
  has_one :github_account
  has_one :user_stat

  has_many :user_tokens
  has_many :user_repository_stat

  accepts_nested_attributes_for :github_account
  accepts_nested_attributes_for :user_tokens
  accepts_nested_attributes_for :user_stat

  enum :account_status, { active: 1, disabled: 0, banned: -1 }

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
