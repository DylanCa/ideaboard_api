class UpdateIssueTableWithGithubData < ActiveRecord::Migration[8.0]
  def change
    change_table :issues do |t|
      t.remove :difficulty  # Removing as it's not from GitHub
      t.rename :github_id, :full_database_id

      # Add new columns
      t.string :url, null: false
      t.integer :number, null: false
      t.string :author_username  # Changed from github_username, can be nil
      t.integer :comments_count, null: false, default: 0
      t.integer :reactions_count, null: false, default: 0
      t.datetime :closed_at

      # Change state from integer to string
      t.change :state, :string, null: false
    end

    add_index :issues, [:github_repository_id, :number]
    add_index :issues, [:github_repository_id, :state]
  end
end
