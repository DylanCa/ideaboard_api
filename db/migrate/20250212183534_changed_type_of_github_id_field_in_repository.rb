class ChangedTypeOfGithubIdFieldInRepository < ActiveRecord::Migration[8.0]
  def change
    remove_index :github_repositories, :repo_id
    remove_column :github_repositories, :repo_id, :integer

    add_column :github_repositories, :github_id, :string
    add_index :github_repositories, :github_id, unique: true
  end
end
