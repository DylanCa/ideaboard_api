class AddLastSyncedAtColumnToRepos < ActiveRecord::Migration[8.0]
  def change
    add_column :github_repositories, :last_synced_at, :datetime
  end
end
