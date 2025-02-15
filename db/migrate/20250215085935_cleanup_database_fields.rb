class CleanupDatabaseFields < ActiveRecord::Migration[8.0]
  def change
    # Remove fields from GithubRepositories
    remove_column :github_repositories, :total_commits_count, :integer
    remove_column :github_repositories, :last_synced_at, :datetime

    # Fix Issues closed_at data type and remove state field
    change_column :issues, :closed_at, :datetime
    remove_column :issues, :state, :string

    # Fix PullRequests closed_at data type
    change_column :pull_requests, :closed_at, :datetime
    remove_column :pull_requests, :state, :string

    # Add new indices
    add_index :issues, [:github_repository_id, :author_username]
    add_index :pull_requests, [:github_repository_id, :author_username]
    add_index :pull_requests, [:author_username, :merged_at]
  end
end