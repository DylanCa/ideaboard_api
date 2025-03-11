class AddGithubWebhookIdToGithubRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :github_repositories, :github_webhook_id, :string
  end
end
