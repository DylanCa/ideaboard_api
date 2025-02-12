class UpdatePullRequestTableWithGithubData < ActiveRecord::Migration[8.0]
  def change
    change_table :pull_requests do |t|
      t.rename :github_id, :full_database_id

      # Add new columns
      t.string :url, null: false
      t.integer :number, null: false
      t.string :author_username  # Changed from github_username, can be nil
      t.datetime :closed_at
      t.boolean :is_draft, null: false, default: false
      t.string :mergeable
      t.boolean :can_be_rebased
      t.integer :total_comments_count, null: false, default: 0
      t.integer :commits, null: false, default: 0
      t.integer :additions, null: false, default: 0
      t.integer :deletions, null: false, default: 0
      t.integer :changed_files, null: false, default: 0

      # Change state from integer to string
      t.change :state, :string, null: false
    end

    add_index :pull_requests, [:github_repository_id, :number]
    add_index :pull_requests, [:github_repository_id, :state]
    add_index :pull_requests, :merged_at
  end
end
