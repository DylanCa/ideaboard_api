class AddAuthorUsernameIndicesToPrAndIssue < ActiveRecord::Migration[8.0]
  def change
    add_index :pull_requests, :author_username
    add_index :issues, :author_username
  end
end
