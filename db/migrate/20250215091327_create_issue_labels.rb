class CreateIssueLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :issue_labels do |t|
      t.integer :issue_id, null: false
      t.integer :label_id, null: false
      t.timestamps
    end

    add_index :issue_labels, :issue_id
    add_index :issue_labels, :label_id
    add_index :issue_labels, [:issue_id, :label_id], unique: true

    add_foreign_key :issue_labels, :issues
    add_foreign_key :issue_labels, :labels
  end
end