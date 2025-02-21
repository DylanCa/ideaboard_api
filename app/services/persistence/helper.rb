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
        metadata_items = items_data.values.flatten
        return unless metadata_items.any?

        model_class.upsert_all(
          metadata_items,
          unique_by: :name,
          returning: %w[id name]
        )

        item_names = metadata_items.map { |item| item[:name] }
        db_items = model_class.where(name: item_names).index_by(&:name)

        join_records = []
        inserted_items.each do |item|
          github_id = item['github_id']
          next unless items_data.key?(github_id)

          items_data[github_id].each do |metadata_item|
            metadata_id = db_items[metadata_item[:name]].id
            join_records << {
              item_key => item['id'],
              metadata_key => metadata_id
            }
          end
        end

        return unless join_records.any?

        join_class.upsert_all(
          join_records,
          unique_by: [item_key, metadata_key],
          returning: false
        )
      end
    end
  end
end