class AddFieldsToUserRepositoryStats < ActiveRecord::Migration[8.0]
  def change
    add_column :user_repository_stats, :closed_prs_count, :integer, default: 0, null: false
    add_column :user_repository_stats, :last_contribution_at, :datetime
    add_column :user_repository_stats, :first_contribution_at, :datetime
    add_column :user_repository_stats, :contribution_streak, :integer, default: 0, null: false

    # Optionally add an index for faster querying of active contributors
    add_index :user_repository_stats, :last_contribution_at
  end
end