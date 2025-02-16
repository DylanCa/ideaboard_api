class CreateGithubAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :github_accounts do |t|
      t.integer :user_id, null: false
      t.integer :github_id, limit: 8, null: false
      t.string :github_username, null: false
      t.string :avatar_url
      t.timestamps
    end

    add_index :github_accounts, :github_id, unique: true
    add_index :github_accounts, :github_username, unique: true
    add_index :github_accounts, :user_id, unique: true
    add_foreign_key :github_accounts, :users
  end
end
