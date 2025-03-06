class SetGithubRepositoryGithubIdToNonNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :github_repositories, :github_id, false
  end
end
