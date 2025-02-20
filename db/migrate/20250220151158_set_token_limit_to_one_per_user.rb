class SetTokenLimitToOnePerUser < ActiveRecord::Migration[8.0]
  def up
    remove_index :user_tokens, :user_id
    add_index :user_tokens, :user_id, unique: true
  end

  def down
    remove_index :user_tokens, :user_id
    add_index :user_tokens, :user_id, unique: false
  end
end
