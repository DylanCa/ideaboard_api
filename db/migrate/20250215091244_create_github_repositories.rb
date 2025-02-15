class CreateGithubRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :github_repositories do |t|
      t.string :full_name, null: false
      t.integer :stars_count, default: 0, null: false
      t.integer :forks_count, default: 0, null: false
      t.boolean :has_contributing, default: false, null: false
      t.datetime :github_created_at, null: false
      t.text :description
      t.boolean :is_fork, default: false, null: false
      t.boolean :archived, default: false, null: false
      t.boolean :disabled, default: false, null: false
      t.string :license
      t.boolean :visible, default: true, null: false
      t.datetime :github_updated_at, null: false
      t.string :github_id
      t.string :author_username
      t.string :language
      t.integer :update_method, default: 0, null: false
      t.datetime :last_polled_at
      t.string :webhook_secret
      t.boolean :app_installed, default: false, null: false
      t.boolean :webhook_installed, default: false, null: false
      t.integer :owner_id
      t.timestamps
    end

    add_index :github_repositories, :full_name, unique: true
    add_index :github_repositories, :github_id, unique: true
    add_index :github_repositories, :github_updated_at
    add_index :github_repositories, :last_polled_at
    add_index :github_repositories, :owner_id
    add_index :github_repositories, :update_method
    add_index :github_repositories, :author_username
    add_index :github_repositories, [:visible, :archived, :disabled]
    add_index :github_repositories, [:stars_count, :visible, :archived, :disabled],
              name: 'idx_on_stars_count_visible_archived_disabled_2b4ce69e99'

    add_foreign_key :github_repositories, :users, column: :owner_id
  end
end