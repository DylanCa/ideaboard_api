class CreateUserRepositoryStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_repository_stats do |t|
      t.integer :user_id, null: false
      t.integer :github_repository_id, null: false
      t.integer :opened_prs_count, default: 0, null: false
      t.integer :merged_prs_count, default: 0, null: false
      t.integer :issues_opened_count, default: 0, null: false
      t.integer :issues_closed_count, default: 0, null: false
      t.integer :issues_with_pr_count, default: 0, null: false
      t.timestamps
    end

    add_index :user_repository_stats, :user_id
    add_index :user_repository_stats, :github_repository_id
    add_index :user_repository_stats, [ :user_id, :github_repository_id ],
              unique: true,
              name: 'idx_on_user_id_github_repository_id_b7aa4510b5'

    add_foreign_key :user_repository_stats, :users
    add_foreign_key :user_repository_stats, :github_repositories
  end
end
