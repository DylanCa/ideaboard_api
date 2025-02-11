class CreateUserRepositoryStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_repository_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.references :github_repository, null: false, foreign_key: true

      # PR metrics
      t.integer :opened_prs_count, null: false, default: 0
      t.integer :merged_prs_count, null: false, default: 0

      # Issue metrics
      t.integer :issues_opened_count, null: false, default: 0
      t.integer :issues_closed_count, null: false, default: 0
      t.integer :issues_with_pr_count, null: false, default: 0

      t.timestamps

      # Ensure unique user-repository combination
      t.index [ :user_id, :github_repository_id ], unique: true
    end
  end
end
