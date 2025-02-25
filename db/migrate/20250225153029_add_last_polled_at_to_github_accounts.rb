class AddLastPolledAtToGithubAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :github_accounts, :last_polled_at, :datetime
    add_index :github_accounts, :last_polled_at
  end
end
