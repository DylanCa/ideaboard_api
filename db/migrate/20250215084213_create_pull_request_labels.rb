class CreatePullRequestLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_request_labels do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true

      t.timestamps
    end

    add_index :pull_request_labels, [:pull_request_id, :label_id], unique: true
  end
end