class UpdateRepositoryColumn < ActiveRecord::Migration[8.0]
  def up
    remove_column :github_repositories, :user_id
    remove_column :github_repositories, :name
    add_column :github_repositories, :author_username, :string

    add_index :github_repositories, :author_username
  end

  def down
    remove_column :github_repositories, :author_username
    add_column :github_repositories, :name, :string
    add_column :github_repositories, :user_id, :integer

    add_index :github_repositories, :user_id
  end
end
