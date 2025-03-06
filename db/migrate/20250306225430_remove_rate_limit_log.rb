class RemoveRateLimitLog < ActiveRecord::Migration[8.0]
  def change
    drop_table :rate_limit_logs
  end
end
