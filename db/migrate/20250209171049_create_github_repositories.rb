class CreateGithubRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :github_repositories do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :language, null: false, foreign_key: true, index: true
      t.integer :repo_id, null: false, limit: 8, index: { unique: true }
      t.string :full_name, null: false, index: { unique: true }
      t.integer :stars_count, null: false, default: 0
      t.integer :forks_count, null: false, default: 0
      t.integer :open_issues_count, null: false, default: 0
      t.boolean :has_license, null: false, default: false
      t.boolean :has_contributing, null: false, default: false
      t.timestamp :github_created_at, null: false

      t.timestamps
    end
  end
end
