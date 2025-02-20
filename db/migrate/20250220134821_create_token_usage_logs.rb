class CreateTokenUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table "token_usage_logs" do |t|
      t.references :user, null: false, foreign_key: true
      t.references :github_repository, null: false, foreign_key: true
      t.datetime :used_at, null: false
      t.integer :usage_type, null: false # personal/contributed/global
      t.integer :points_used, null: false
      t.integer :points_remaining, null: false
      t.timestamps

      t.index [:user_id, :github_repository_id, :used_at]
      t.index :used_at
      t.index :usage_type
    end
  end
end
