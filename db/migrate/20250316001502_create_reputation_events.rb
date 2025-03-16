class CreateReputationEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :reputation_events do |t|
      # Who received the points
      t.references :user, null: false, foreign_key: true

      # What triggered the points (optional associations)
      t.references :github_repository, foreign_key: true
      t.references :pull_request, foreign_key: true
      t.references :issue, foreign_key: true

      # Point details
      t.integer :points_change, null: false  # Can be positive or negative
      t.jsonb :points_breakdown, null: false # Detailed breakdown
      t.string :event_type, null: false      # PR_MERGED, ISSUE_OPENED, PR_REJECTED, etc.
      t.string :description                  # Human-readable description

      # When the points were earned
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :reputation_events, [ :user_id, :occurred_at ]
    add_index :reputation_events, :event_type
    add_index :reputation_events, :occurred_at
  end
end
