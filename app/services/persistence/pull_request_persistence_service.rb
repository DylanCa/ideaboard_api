  module Persistence
    class PullRequestPersistenceService
      extend T::Sig

      def self.persist_many(pull_requests, repo)
        validate_bulk_input!(pull_requests)

        pull_requests = pull_requests.map { |pr| Github::PullRequest.from_github(pr, repo.id) }
        attributes_list = pull_requests.map(&:stringify_keys)

        repo.pull_requests.upsert_all(
          attributes_list,
          unique_by: :github_id,
          returning: false
        )
      end

      private

      def self.validate_bulk_input!(pull_requests)
        raise ArgumentError, "Pull Requests cannot be nil" if pull_requests.nil?
      end
    end
  end
