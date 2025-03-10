module Persistence
  class Helper
    class << self
      def insert_items_labels_if_any(labels, inserted_items, type)
        if type == :prs
          label_type = Label
          model = PullRequestLabel
          item_key = :pull_request_id
          metadata_key = :label_id

        elsif type == :issues
          label_type = Label
          model = IssueLabel
          item_key = :issue_id
          metadata_key = :label_id

        elsif type == :repositories
          label_type = Topic
          model = GithubRepositoryTopic
          item_key = :github_repository_id
          metadata_key = :topic_id

        else
          raise
        end

        insert_items_metadata(
          labels,
          inserted_items,
          label_type,
          model,
          item_key,
          metadata_key
        )
      end

      def label_cache
        @label_cache ||= {}
      end

      def reset_cache
        @label_cache = {}
      end

      def get_label_by_name(name, repo_id = nil)
        cache_key = "#{name}_#{repo_id}"
        label_cache[cache_key]
      end

      def preload_labels(label_names, repo_id)
        return if label_names.blank? || repo_id.nil?

        label_names = Array(label_names)
        return if label_names.empty? || !repo_id.is_a?(Integer)

        uncached_names = label_names.reject do |name|
          label_cache.key?("#{name}_#{repo_id}")
        end

        return if uncached_names.empty?

        existing_labels = Label.where(
          name: uncached_names,
          github_repository_id: repo_id
        ).index_by(&:name)

        existing_labels.each do |name, label|
          label_cache["#{name}_#{repo_id}"] = label
        end

        missing_names = uncached_names - existing_labels.keys

        if missing_names.any?
          new_labels = missing_names.map do |name|
            {
              name: name,
              github_repository_id: repo_id,
              is_bug: false,
              created_at: Time.current,
              updated_at: Time.current
            }
          end

          begin
            created_labels = Label.insert_all(
              new_labels,
              returning: %w[id name github_repository_id]
            )

            created_labels.rows.each do |id, name, repository_id|
              label = Label.new(
                id: id,
                name: name,
                github_repository_id: repository_id
              )
              label_cache["#{name}_#{repository_id}"] = label
            end
          rescue => e
            Rails.logger.error "Error creating labels: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
          end
        end
      end

      private

      def insert_items_metadata(items_data, inserted_items, model_class, join_class, item_key, metadata_key)
        return unless items_data.any?

        metadata_names = items_data.values.flatten.map { |item| item[:name] }.uniq

        repo_id = nil
        if model_class == Label
          first_item = items_data.values.flatten.first
          repo_id = first_item[:github_repository_id] if first_item&.key?(:github_repository_id)
        end

        if model_class == Label
          preload_labels(metadata_names, repo_id)
          db_items = metadata_names.each_with_object({}) do |name, hash|
            hash[name] = get_label_by_name(name, repo_id)
          end
        else
          existing_items = model_class.where(name: metadata_names).index_by(&:name)
          missing_names = metadata_names - existing_items.keys

          if missing_names.any?
            new_items = missing_names.map { |name| { name: name } }
            created_items = model_class.insert_all(new_items, returning: %w[id name])

            if created_items.rows.any?
              model_class.where(id: created_items.rows.map(&:first)).each do |item|
                existing_items[item.name] = item
              end
            end
          end

          db_items = metadata_names.each_with_object({}) do |name, hash|
            hash[name] = existing_items[name]
          end
        end

        join_records = []
        inserted_items.each do |item|
          github_id = item["github_id"]
          next unless github_id && items_data.key?(github_id)
          next unless items_data[github_id]

          items_data[github_id].each do |metadata_item|
            next unless metadata_item && metadata_item[:name] && db_items[metadata_item[:name]]
            metadata_id = db_items[metadata_item[:name]].id
            join_records << { item_key => item["id"], metadata_key => metadata_id }
          end
        end

        return if join_records.empty?

        join_records.each_slice(1000) do |batch|
          join_class.upsert_all(batch, unique_by: [ item_key, metadata_key ], returning: false)
        end
      end
    end
  end
end
