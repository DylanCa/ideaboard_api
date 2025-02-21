module Persistence
  class IssuePersistenceService
    extend T::Sig

    def self.persist_many(issues, repo)
      validate_bulk_input!(issues, repo)

      issues_to_insert = []
      raw_issues = {}

      # Prepare all data before any database operations
      issues.each do |issue|
        unless issue.labels.nil?
          labels = issue.labels.nodes.map { |l| Github::Label.from_github(l, repo.id).stringify_keys }
          raw_issues[issue.id] = labels
        end

        issues_to_insert << Github::Issue.from_github(issue, repo.id).stringify_keys
      end

      # Bulk insert issues
      inserted_issues = repo.issues.upsert_all(
        issues_to_insert,
        unique_by: :github_id,
        returning: %w[id github_id]
      )

      # Insert labels using the optimized helper
      Persistence::Helper.insert_issues_labels_if_any(raw_issues, inserted_issues)
    end

    private

    def self.validate_bulk_input!(issues, repo)
      raise ArgumentError, "Issues cannot be nil" if issues.nil?
      raise ArgumentError, "GitHub Repository cannot be nil" if repo.nil?
    end
  end
end
