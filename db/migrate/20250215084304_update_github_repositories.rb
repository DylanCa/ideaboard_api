class UpdateGithubRepositories < ActiveRecord::Migration[8.0]
  def change
    change_table :github_repositories do |t|
      t.integer :update_method, null: false, default: 0
      t.datetime :last_polled_at
      t.string :webhook_secret
      t.boolean :app_installed, null: false, default: false
      t.boolean :webhook_installed, null: false, default: false
      t.references :owner, foreign_key: { to_table: :users }
    end

    add_index :github_repositories, :update_method
    add_index :github_repositories, :last_polled_at
  end
end