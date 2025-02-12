class UpdatedRepositoryTableLanguageIdField < ActiveRecord::Migration[8.0]
  def change
    change_column_null :github_repositories, :language_id, true
  end
end
