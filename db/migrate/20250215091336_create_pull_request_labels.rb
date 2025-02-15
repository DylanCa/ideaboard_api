class CreatePullRequestLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_request_labels do |t|
      t.integer :pull_request_id, null: false
      t.integer :label_id, null: false
      t.timestamps
    end

    add_index :pull_request_labels, :pull_request_id
    add_index :pull_request_labels, :label_id
    add_index :pull_request_labels, [:pull_request_id, :label_id], unique: true

    add_foreign_key :pull_request_labels, :pull_requests
    add_foreign_key :pull_request_labels, :labels
  end
end