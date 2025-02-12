class RemoveGithubUsernameFieldInIndex < ActiveRecord::Migration[8.0]
  def change
    remove_column :issues, :github_username, :string
  end
end
