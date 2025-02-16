class CreatePullRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_requests do |t|
      t.integer :github_repository_id, null: false
      t.string :github_id
      t.string :title, null: false
      t.datetime :merged_at
      t.datetime :github_created_at, null: false
      t.datetime :github_updated_at, null: false
      t.string :url, null: false
      t.integer :number, null: false
      t.string :author_username
      t.boolean :is_draft, default: false, null: false
      t.integer :commits
      t.integer :total_comments_count
      t.datetime :closed_at
      t.timestamps
    end

    add_index :pull_requests, :github_id, unique: true
    add_index :pull_requests, :github_repository_id
    add_index :pull_requests, :author_username
    add_index :pull_requests, :merged_at
    add_index :pull_requests, [ :github_repository_id, :number ]
    add_index :pull_requests, [ :author_username, :merged_at ]
    add_index :pull_requests, [ :github_repository_id, :author_username ],
              name: 'idx_on_github_repository_id_author_username_558298bf1e'

    add_foreign_key :pull_requests, :github_repositories
  end
end
