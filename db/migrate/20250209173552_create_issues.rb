class CreateIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :issues do |t|
      t.references :github_repository, null: false, foreign_key: true, index: true
      t.integer :github_id, null: false, limit: 8, index: { unique: true }
      t.string :github_username, null: false, index: { unique: true }
      t.string :title, null: false
      t.integer :state, null: false, default: 0, index: true
      t.integer :difficulty, null: false, default: 0
      t.timestamp :github_created_at, null: false
      t.timestamp :github_updated_at, null: false

      t.timestamps
    end
  end
end
