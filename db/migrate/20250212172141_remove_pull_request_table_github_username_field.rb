class RemovePullRequestTableGithubUsernameField < ActiveRecord::Migration[8.0]
  def change
    remove_column :pull_requests, :github_username, :string
  end
end
