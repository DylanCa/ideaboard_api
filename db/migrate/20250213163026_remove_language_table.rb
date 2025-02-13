class RemoveLanguageTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :languages
    remove_column :github_repositories, :language_id
  end
end
