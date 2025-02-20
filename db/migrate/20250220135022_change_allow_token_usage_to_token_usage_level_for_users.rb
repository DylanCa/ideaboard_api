class ChangeAllowTokenUsageToTokenUsageLevelForUsers < ActiveRecord::Migration[8.0]
  def up
    remove_column :users, :allow_token_usage, :boolean, default: false
    add_column :users, :token_usage_level, :integer, default: 0
  end

  def down
    remove_column :users, :token_usage_level, :integer, default: true
    add_column :users, :allow_token_usage, :boolean, default: false
  end
end
