module Services
  module Persistence
    class PullRequestPersistenceService
      extend T::Sig

      sig { params(pull_requests: T::Array[Github::PullRequest]).void }
      def self.persist_many(pull_requests)
        validate_bulk_input!(pull_requests)

        attributes_list = pull_requests.map do |pr|
          # Convert GitHub's string state to our enum values
          state_value = if pr.merged_at.present?
                          PullRequest.states[:merged]
                        elsif pr.state == 'closed'
                          PullRequest.states[:closed]
                        else
                          PullRequest.states[:open]
                        end

          {
            github_repository_id: pr.repository_id,
            full_database_id: pr.full_database_id,
            title: pr.title,
            url: pr.url,
            number: pr.number,
            state: state_value, # Using the converted enum value
            author_username: pr.author_username,
            merged_at: pr.merged_at,
            closed_at: pr.closed_at,
            github_created_at: pr.created_at,
            github_updated_at: pr.updated_at,
            is_draft: pr.is_draft,
            mergeable: pr.mergeable,
            can_be_rebased: pr.can_be_rebased,
            total_comments_count: pr.total_comments_count,
            commits: pr.commits,
            additions: pr.additions,
            deletions: pr.deletions,
            changed_files: pr.changed_files,
            points_awarded: 0  # Default value
          }
        end

        PullRequest.upsert_all(
          attributes_list,
          unique_by: :full_database_id,
        )
      end

      private

      sig { params(pull_requests: T::Array[Github::PullRequest]).void }
      def self.validate_bulk_input!(pull_requests)
        raise ArgumentError, "Pull Requests cannot be nil" if pull_requests.nil?
      end
    end
  end
end
