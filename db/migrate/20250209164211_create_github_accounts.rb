class CreateGithubAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :github_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :github_id, null: false, limit: 8, index: { unique: true }
      t.string :github_username, null: false, index: { unique: true }
      t.string :oauth_access_token, null: false
      t.string :oauth_refresh_token, null: false
      t.string :avatar_url

      t.timestamps
    end
  end
end
