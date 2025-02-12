class UpdateGithubRepositoriesStructure < ActiveRecord::Migration[8.0]
  def change
    # Remove old table (since we're merging Projects into it)
    drop_table :projects

    # Remove and modify columns
    change_table :github_repositories do |t|
      # Remove old columns
      t.remove :project_id
      t.remove :open_issues_count
      t.remove :has_license

      # Add new columns
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :is_fork, null: false, default: false
      t.boolean :archived, null: false, default: false
      t.boolean :disabled, null: false, default: false
      t.string :license_key
      t.boolean :visible, null: false, default: true
      t.datetime :github_updated_at, null: false
    end

    # Add new indexes
    add_index :github_repositories, [ :stars_count, :visible, :archived, :disabled ]
    add_index :github_repositories, :github_updated_at
    add_index :github_repositories, [ :visible, :archived, :disabled ]
  end
end
