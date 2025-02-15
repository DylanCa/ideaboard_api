  module Persistence
    class IssuePersistenceService
      extend T::Sig

      def self.persist_many(issues, repo)
        validate_bulk_input!(issues, repo)

        issues = issues.map { |issue| Github::Issue.from_github(issue, repo.id) }
        attributes_list = issues.map(&:stringify_keys)

        repo.issues.upsert_all(
          attributes_list,
          unique_by: :github_id,
          returning: false
        )
      end

      private

      def self.validate_bulk_input!(issues, repo)
        raise ArgumentError, "Issues cannot be nil" if issues.nil?
        raise ArgumentError, "GitHub Repository cannot be nil" if repo.nil?
      end
    end
  end
