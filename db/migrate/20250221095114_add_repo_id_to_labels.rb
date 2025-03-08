class AddRepoIdToLabels < ActiveRecord::Migration[8.0]
  def change
    add_column :labels, :github_repository_id, :integer, null: false
    add_foreign_key :labels, :github_repositories

    add_index :labels, :github_repository_id
  end
end
