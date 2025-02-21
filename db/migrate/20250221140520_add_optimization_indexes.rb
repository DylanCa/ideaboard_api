class AddOptimizationIndexes < ActiveRecord::Migration[8.0]
  def change
    # Improve performance for label lookups
    add_index :labels, [:name, :github_repository_id], name: 'idx_labels_on_name_and_repo_id'

    # Improve performance for token usage queries
    add_index :token_usage_logs, [:created_at, :user_id], name: 'idx_token_usage_logs_on_created_at_and_user_id'

    # Improve performance for fetching user's repositories
    add_index :github_repositories, [:author_username, :stars_count], name: 'idx_repos_on_author_and_stars'

    # Improve performance for fetching user's contributions
    add_index :pull_requests, [:author_username, :github_created_at], name: 'idx_prs_on_author_and_created_at'
    add_index :issues, [:author_username, :github_created_at], name: 'idx_issues_on_author_and_created_at'

    # Improve performance for rate limit queries
    add_index :rate_limit_logs, [:token_owner_id, :executed_at], name: 'idx_rate_limit_logs_on_owner_and_time'
  end
end