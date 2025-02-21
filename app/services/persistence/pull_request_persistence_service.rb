module Persistence
  class PullRequestPersistenceService
    extend T::Sig

    def self.persist_many(pull_requests, repo)
      validate_bulk_input!(pull_requests)

      prs = []
      raw_labels = {}

      # Prepare all data before any database operations
      pull_requests.each do |pr|
        unless pr.labels.nil?
          labels = pr.labels.nodes.map { |l| Github::Label.from_github(l, repo.id).stringify_keys }
          raw_labels[pr.id] = labels
        end

        prs << Github::PullRequest.from_github(pr, repo.id).stringify_keys
      end

      # Perform bulk insertion for pull requests
      inserted_prs = repo.pull_requests.upsert_all(
        prs,
        unique_by: :github_id,
        returning: %w[id github_id]
      )

      # Insert labels with the optimized helper
      Persistence::Helper.insert_prs_labels_if_any(raw_labels, inserted_prs)
    end

    private

    def self.validate_bulk_input!(pull_requests)
      raise ArgumentError, "Pull Requests cannot be nil" if pull_requests.nil?
    end
  end
end