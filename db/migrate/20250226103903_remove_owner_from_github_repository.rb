class RemoveOwnerFromGithubRepository < ActiveRecord::Migration[8.0]
  def up
    remove_index :github_repositories, :owner_id
    remove_column :github_repositories, :owner_id, :integer
  end

  def down
    add_column :github_repositories, :owner_id, :integer
    add_index :github_repositories, :owner_id
  end
end
