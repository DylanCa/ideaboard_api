class RemoveOauthTokensFromGithubAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_column :github_accounts, :oauth_access_token, :string
    remove_column :github_accounts, :oauth_refresh_token, :string
  end
end
