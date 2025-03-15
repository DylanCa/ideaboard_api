class CreatePullRequestIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_request_issues do |t|
      # PR identifiers
      t.string :pr_repository, null: false
      t.integer :pr_number, null: false

      # Issue identifiers
      t.string :issue_repository, null: false
      t.integer :issue_number, null: false

      # Relationship type
      t.boolean :closes_issue, default: true, null: false

      # Processing tracking
      t.datetime :processed_at

      t.timestamps
    end

    # Create indexes for efficient lookups
    add_index :pull_request_issues, [ :pr_repository, :pr_number ], name: 'idx_on_pr_repo_and_number'
    add_index :pull_request_issues, [ :issue_repository, :issue_number ], name: 'idx_on_issue_repo_and_number'
    add_index :pull_request_issues, [ :pr_repository, :pr_number, :issue_repository, :issue_number ],
              unique: true, name: 'idx_on_pr_issue_unique'
    add_index :pull_request_issues, :processed_at
  end
end
