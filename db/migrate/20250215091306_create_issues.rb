class CreateIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :issues do |t|
      t.integer :github_repository_id, null: false
      t.string :github_id
      t.string :title, null: false
      t.datetime :github_created_at, null: false
      t.datetime :github_updated_at, null: false
      t.string :url, null: false
      t.integer :number, null: false
      t.string :author_username
      t.datetime :closed_at
      t.integer :comments_count
      t.timestamps
    end

    add_index :issues, :github_id, unique: true
    add_index :issues, :github_repository_id
    add_index :issues, :author_username
    add_index :issues, [ :github_repository_id, :number ]
    add_index :issues, [ :github_repository_id, :author_username ]

    add_foreign_key :issues, :github_repositories
  end
end
