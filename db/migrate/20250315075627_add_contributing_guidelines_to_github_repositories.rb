class AddContributingGuidelinesToGithubRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :github_repositories, :contributing_guidelines, :text
    add_column :github_repositories, :contributing_url, :string
  end
end
