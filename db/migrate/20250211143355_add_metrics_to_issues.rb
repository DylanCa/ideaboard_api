class AddMetricsToIssues < ActiveRecord::Migration[8.0]
  def change
    change_table :issues do |t|
      t.integer :closed_by_pull_request_id, null: true, index: true
      t.integer :reaction_count, null: false, default: 0, index: true
    end
  end
end
