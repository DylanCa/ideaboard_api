class AddLanguageNameToRepos < ActiveRecord::Migration[8.0]
  def change
    add_column :github_repositories, :language, :string
  end
end
