class AddUniqueIndexOnGithubRepositoryTopics < ActiveRecord::Migration[8.0]
  def up
    rename_column :github_repository_topics, :tag_id, :topic_id
    add_index :github_repository_topics, [ :github_repository_id, :topic_id ], unique: true
  end

  def down
    remove_index :github_repository_topics, column: [ :github_repository_id, :topic_id ]
    rename_column :github_repository_topics, :topic_id, :tag_id
  end
end
