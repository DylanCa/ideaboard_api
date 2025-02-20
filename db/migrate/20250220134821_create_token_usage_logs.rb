class CreateTokenUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table "token_usage_logs" do |t|
      t.references :user, foreign_key: true
      t.references :github_repository, foreign_key: true
      t.string :query, null: false
      t.string :variables
      t.integer :usage_type, null: false # personal/contributed/global
      t.integer :points_used, null: false
      t.integer :points_remaining, null: false
      t.timestamps

      t.index [ :user_id, :github_repository_id ]
      t.index :usage_type
      t.index :query
    end
  end
end
