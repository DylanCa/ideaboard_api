class RenameTagsForTopics < ActiveRecord::Migration[8.0]
  def change
    rename_table :tags, :topics
    rename_table :github_repository_tags, :github_repository_topics
  end
end
