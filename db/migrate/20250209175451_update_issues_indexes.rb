class UpdateIssuesIndexes < ActiveRecord::Migration[8.0]
  def change
    remove_index :issues, :github_username
    add_index :issues, :github_username, unique: false
    add_index :issues, :difficulty
  end
end
