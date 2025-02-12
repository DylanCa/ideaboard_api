class AddMetricsToPullRequests < ActiveRecord::Migration[8.0]
  def change
    change_table :pull_requests do |t|
      t.boolean :has__received_rfc, null: false, default: false
    end
  end
end
