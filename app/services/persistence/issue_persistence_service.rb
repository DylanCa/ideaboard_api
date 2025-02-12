module Services
  module Persistence
    class IssuePersistenceService
      extend T::Sig

      sig { params(issues: T::Array[Github::Issue], github_repository_id: Integer).void }
      def self.persist_many(issues, github_repository_id)
        validate_bulk_input!(issues, github_repository_id)

        attributes_list = issues.map do |issue|
          {
            github_repository_id: github_repository_id,
            full_database_id: issue.full_database_id,
            title: issue.title,
            url: issue.url,
            number: issue.number,
            state: issue.state,
            author_username: issue.author_username,
            comments_count: issue.comments_count,
            reactions_count: issue.reactions_count,
            github_created_at: issue.created_at,
            github_updated_at: issue.updated_at,
            closed_at: issue.closed_at
          }
        end

        Issue.upsert_all(
          attributes_list,
          unique_by: :full_database_id,
          returning: false
        )
      end

      private

      sig { params(issues: T::Array[Github::Issue], github_repository_id: Integer).void }
      def self.validate_bulk_input!(issues, github_repository_id)
        raise ArgumentError, "Issues cannot be nil" if issues.nil?
        raise ArgumentError, "GitHub Repository ID cannot be nil" if github_repository_id.nil?
      end
    end
  end
end
