class User < ApplicationRecord
  has_one :github_account
  has_one :user_stat

  has_many :projects
  has_many :user_tokens

  accepts_nested_attributes_for :github_account
  accepts_nested_attributes_for :user_tokens
  accepts_nested_attributes_for :user_stat

  enum :account_status, { active: 1, disabled: 0, banned: -1 }

  scope :with_github_id, ->(github_id) {
    joins(:github_account).where(github_account: { github_id: github_id })
  }

  def github_client
    client = Octokit::Client.new(access_token: github_account.oauth_access_token)
    return client if client.user_authenticated?

    # TODO: Implement refresh token logic here
    raise Octokit::Error
  end
end
