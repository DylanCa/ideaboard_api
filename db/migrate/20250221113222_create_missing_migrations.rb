class CreateMissingMigrations < ActiveRecord::Migration[8.0]
  def change
    add_index :token_usage_logs, [ :query, :created_at ]
    add_index :issues, [ :github_repository_id, :github_updated_at ]
    add_index :pull_requests, [ :github_repository_id, :github_updated_at ]
  end
end
