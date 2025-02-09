class CreateProjectStats < ActiveRecord::Migration[8.0]
  def change
    create_table :project_stats do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.float :rank_score, null: false, default: 0.0, index: true
      t.timestamp :last_activity_at, null: false

      t.timestamps
    end
  end
end
