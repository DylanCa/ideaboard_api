module Persistence
  class Helper
    class << self

      def insert_repos_topics_if_any(raw_topics, inserted_repos)
        insert_items_metadata(
          raw_topics,
          inserted_repos,
          Topic,
          GithubRepositoryTopic,
          :github_repository_id,
          :topic_id
        )
      end

      def insert_prs_labels_if_any(raw_labels, inserted_prs)
        insert_items_metadata(
          raw_labels,
          inserted_prs,
          Label,
          PullRequestLabel,
          :pull_request_id,
          :label_id
        )
      end

      def insert_issues_labels_if_any(raw_labels, inserted_issues)
        insert_items_metadata(
          raw_labels,
          inserted_issues,
          Label,
          IssueLabel,
          :issue_id,
          :label_id
        )
      end

      private

      def insert_items_metadata(items_data, inserted_items, model_class, join_class, item_key, metadata_key)
        return unless items_data.any?

        # Extract unique metadata items to reduce duplicate processing
        metadata_names = items_data.values.flatten.map { |item| item[:name] }.uniq

        # Use find_or_create_by with bulk operations instead of separate upsert + select
        db_items = {}
        ActiveRecord::Base.transaction do
          metadata_names.each do |name|
            db_items[name] = model_class.find_or_create_by(name: name)
          end
        end

        # Build join records in memory, insert in a single operation
        join_records = []
        inserted_items.each do |item|
          github_id = item['github_id']
          next unless items_data.key?(github_id)

          items_data[github_id].each do |metadata_item|
            metadata_id = db_items[metadata_item[:name]].id
            join_records << { item_key => item['id'], metadata_key => metadata_id }
          end
        end

        # Insert in larger batches (e.g., 1000 at a time)
        join_records.each_slice(1000) do |batch|
          join_class.upsert_all(batch, unique_by: [item_key, metadata_key], returning: false)
        end
      end
    end
  end
end