class CreateRateLimitLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :rate_limit_logs do |t|
      t.string :token_owner_type, null: false
      t.bigint :token_owner_id, null: false
      t.string :query_name, null: false
      t.integer :cost, null: false
      t.integer :remaining_points, null: false
      t.datetime :reset_at, null: false
      t.datetime :executed_at, null: false
      t.timestamps
    end

    add_index :rate_limit_logs, [ :token_owner_type, :token_owner_id ]
    add_index :rate_limit_logs, :executed_at
  end
end
