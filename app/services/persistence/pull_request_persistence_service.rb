  module Persistence
    class PullRequestPersistenceService
      extend T::Sig

      def self.persist_many(pull_requests, repo)
        validate_bulk_input!(pull_requests)

        prs = []
        raw_labels = {}

        pull_requests.each do |pr|
          unless pr.labels.nil?
            labels = pr.labels.nodes.map { |l| Github::Label.from_github(l, repo.id).stringify_keys }
            raw_labels[pr.id] = labels
          end

          prs << Github::PullRequest.from_github(pr, repo.id).stringify_keys
        end

        inserted_prs = repo.pull_requests.upsert_all(
          prs,
          unique_by: :github_id,
          returning: %w[id github_id]
        )

        Helper.insert_prs_labels_if_any(raw_labels, inserted_prs)
      end

      private

      def self.validate_bulk_input!(pull_requests)
        raise ArgumentError, "Pull Requests cannot be nil" if pull_requests.nil?
      end
    end
  end
