class RemoveUnnecessaryColumnsFromPullRequests < ActiveRecord::Migration[8.0]
  def change
      remove_column :pull_requests, :points_awarded, :integer
      remove_column :pull_requests, :has_received_rfc, :boolean
      remove_column :pull_requests, :mergeable, :boolean
      remove_column :pull_requests, :can_be_rebased, :boolean
      remove_column :pull_requests, :additions, :integer
      remove_column :pull_requests, :deletions, :integer
      remove_column :pull_requests, :changed_files, :integer
      remove_column :pull_requests, :has__received_rfc, :boolean

      rename_column :pull_requests, :full_database_id, :github_id
  end
end