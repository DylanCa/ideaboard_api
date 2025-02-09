class CreateGithubRepositoryTags < ActiveRecord::Migration[8.0]
  def change
    create_table :github_repository_tags do |t|
      t.references :github_repository, null: false, foreign_key: true, index: true
      t.references :tag, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :github_repository_tags, [ :github_repository_id, :tag_id ], unique: true, name: 'index_repository_tags_uniqueness'
  end
end
