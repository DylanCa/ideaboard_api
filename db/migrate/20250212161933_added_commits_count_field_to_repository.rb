class AddedCommitsCountFieldToRepository < ActiveRecord::Migration[8.0]
  def change
    change_table :github_repositories do |t|
      t.integer :total_commits_count, default: 0
    end
  end
end
