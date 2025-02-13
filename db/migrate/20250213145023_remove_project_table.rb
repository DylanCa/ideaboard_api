class RemoveProjectStatsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :project_stats
  end
end
