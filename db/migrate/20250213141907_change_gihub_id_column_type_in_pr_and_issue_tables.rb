class ChangeGihubIdColumnTypeInPrAndIssueTables < ActiveRecord::Migration[8.0]
  def up
    change_column :pull_requests, :github_id, :string
    change_column :issues, :github_id, :string
  end

  def down
    change_column :pull_requests, :github_id, :bigint
    change_column :issues, :github_id, :bigint
  end
end
