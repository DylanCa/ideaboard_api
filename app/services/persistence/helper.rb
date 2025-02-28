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

      # Cache for labels to avoid repeated DB queries
      def label_cache
        @label_cache ||= {}
      end

      # Reset the cache - call this between major operations
      def reset_cache
        @label_cache = {}
      end

      # Get label by name, using cache
      def get_label_by_name(name, repo_id = nil)
        cache_key = "#{name}_#{repo_id}"
        label_cache[cache_key]
      end

      # Pre-load a batch of labels by name
      def preload_labels(label_names, repo_id)
        # Validate input
        return if label_names.blank? || repo_id.nil?

        # Ensure label_names is an array
        label_names = Array(label_names)

        # Skip if no labels to load or repo_id is invalid
        return if label_names.empty? || !repo_id.is_a?(Integer)

        # Determine which labels are not already cached
        uncached_names = label_names.reject do |name|
          label_cache.key?("#{name}_#{repo_id}")
        end

        return if uncached_names.empty?

        # Fetch existing labels in a single query
        existing_labels = Label.where(
          name: uncached_names,
          github_repository_id: repo_id
        ).index_by(&:name)

        # Cache existing labels
        existing_labels.each do |name, label|
          label_cache["#{name}_#{repo_id}"] = label
        end

        # Prepare to create missing labels
        missing_names = uncached_names - existing_labels.keys

        # Create missing labels if any
        if missing_names.any?
          # Prepare label creation data
          new_labels = missing_names.map do |name|
            {
              name: name,
              github_repository_id: repo_id,
              is_bug: false,  # Default value, can be adjusted
              created_at: Time.current,
              updated_at: Time.current
            }
          end

          # Batch insert missing labels
          begin
            created_labels = Label.insert_all(
              new_labels,
              returning: %w[id name github_repository_id]
            )

            # Cache newly created labels
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

        # Collect all metadata names for batch processing
        metadata_names = items_data.values.flatten.map { |item| item[:name] }.uniq

        # Validate repo_id extraction
        repo_id = nil
        if model_class == Label
          # Try to extract repo_id from the first item
          first_item = items_data.values.flatten.first
          repo_id = first_item[:github_repository_id] if first_item&.key?(:github_repository_id)
        end

        # Use our preloading method for labels
        if model_class == Label
          preload_labels(metadata_names, repo_id)
          db_items = metadata_names.each_with_object({}) do |name, hash|
            hash[name] = get_label_by_name(name, repo_id)
          end
        else
          # For other metadata types like topics, use batch processing
          existing_items = model_class.where(name: metadata_names).index_by(&:name)

          # Identify missing items
          missing_names = metadata_names - existing_items.keys

          # Create missing items in batch
          if missing_names.any?
            new_items = missing_names.map { |name| { name: name } }
            created_items = model_class.insert_all(new_items, returning: %w[id name])

            # Refresh our existing_items hash with newly created records
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

        # Build join records in memory
        join_records = []
        inserted_items.each do |item|
          github_id = item["github_id"]
          next unless github_id && items_data.key?(github_id)
          next unless items_data[github_id] # Skip if nil

          items_data[github_id].each do |metadata_item|
            next unless metadata_item && metadata_item[:name] && db_items[metadata_item[:name]]
            metadata_id = db_items[metadata_item[:name]].id
            join_records << { item_key => item["id"], metadata_key => metadata_id }
          end
        end

        # Only proceed if we have records to insert
        return if join_records.empty?

        # Insert in larger batches
        join_records.each_slice(1000) do |batch|
          join_class.upsert_all(batch, unique_by: [ item_key, metadata_key ], returning: false)
        end
      end
    end
  end
end
