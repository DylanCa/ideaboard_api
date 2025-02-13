class RemoveUnnecessaryColumnsFromIssues < ActiveRecord::Migration[8.0]
  def change
      remove_column :issues, :closed_by_pull_request_id, :integer
      remove_column :issues, :reaction_count, :integer
      remove_column :issues, :reactions_count, :integer

      rename_column :issues, :full_database_id, :github_id
  end
end