class CreateGithubRepositoryTags < ActiveRecord::Migration[8.0]
  def change
    create_table :github_repository_tags do |t|
      t.integer :github_repository_id, null: false
      t.integer :tag_id, null: false
      t.timestamps
    end

    add_index :github_repository_tags, :github_repository_id
    add_index :github_repository_tags, :tag_id
    add_index :github_repository_tags, [:github_repository_id, :tag_id],
              unique: true,
              name: 'index_repository_tags_uniqueness'

    add_foreign_key :github_repository_tags, :github_repositories
    add_foreign_key :github_repository_tags, :tags
  end
end