class UpdatePullRequestsIndexes < ActiveRecord::Migration[8.0]
  def change
    remove_index :pull_requests, :github_username
    add_index :pull_requests, :github_username, unique: false
    add_index :pull_requests, :merged_at
  end
end
