class AddRepoIdToLabels < ActiveRecord::Migration[8.0]
  def change
    # First add the column
    add_column :labels, :github_repository_id, :integer, null: false

    # Then add the foreign key constraint
    add_foreign_key :labels, :github_repositories

    # Add an index for better performance
    add_index :labels, :github_repository_id
  end
end
