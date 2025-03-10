module Persistence
  class ItemPersistenceService
    extend T::Sig

    def self.persist_many(items, repo, type: :prs)
      validate_bulk_input!(items, repo, type)

      items_to_insert = []
      labels_for_item = {}

      items.each do |issue|
        unless issue.labels.nil?
          labels = issue.labels.nodes.map { |l| Github::Label.from_github(l, repo.id).stringify_keys }
          labels_for_item[issue.id] = labels
        end

        if type == :prs
          items_to_insert << Github::PullRequest.from_github(issue, repo.id).stringify_keys
        else
          items_to_insert << Github::Issue.from_github(issue, repo.id).stringify_keys
        end
      end

      if type == :prs
        inserted_items = repo.pull_requests.upsert_all(
          items_to_insert,
          unique_by: :github_id,
          returning: %w[id github_id]
        )
      else
        inserted_items = repo.issues.upsert_all(
          items_to_insert,
          unique_by: :github_id,
          returning: %w[id github_id]
        )
      end

      Persistence::Helper.insert_items_labels_if_any(labels_for_item, inserted_items, type)
    end

    private

    def self.validate_bulk_input!(items, repo, type)
      raise ArgumentError, "Items cannot be nil" if items.nil?
      raise ArgumentError, "GitHub Repository cannot be nil" if repo.nil?
      raise ArgumentError, "Type should be either :prs or :issues" unless type == :prs || type == :issues
    end
  end
end
