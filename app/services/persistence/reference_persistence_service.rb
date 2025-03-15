# app/services/persistence/reference_persistence_service.rb
module Persistence
  class ReferencePersistenceService
    class << self
      def store_pr_issue_references(items)
        references = []

        items.each do |item|
          # Skip items without closing issues references
          next unless item.respond_to?(:closing_issues_references) &&
            item.closing_issues_references&.nodes

          # Get PR details (make sure repository is available)
          next unless item.respond_to?(:repository) && item.repository&.name_with_owner

          pr_repo = item.repository.name_with_owner
          pr_number = item.number

          # Process each referenced issue
          item.closing_issues_references.nodes.each do |issue|
            references << {
              pr_repository: pr_repo,
              pr_number: pr_number,
              issue_repository: issue.repository.name_with_owner,
              issue_number: issue.number,
              closes_issue: true,
              created_at: Time.current,
              updated_at: Time.current
            }
          end
        end

        # Bulk insert if we have references
        if references.any?
          PullRequestIssue.upsert_all(
            references,
            unique_by: [ :pr_repository, :pr_number, :issue_repository, :issue_number ]
          )
        end
      end

      def store_issue_pr_references(items)
        references = []

        items.each do |item|
          # Skip items without closing PR references
          next unless item.respond_to?(:closed_by_pull_requests) &&
            item.closed_by_pull_requests&.nodes

          # Get issue details (make sure repository is available)
          next unless item.respond_to?(:repository) && item.repository&.name_with_owner

          issue_repo = item.repository.name_with_owner
          issue_number = item.number

          # Process each referenced PR
          item.closed_by_pull_requests.nodes.each do |pr|
            references << {
              pr_repository: pr.repository.name_with_owner,
              pr_number: pr.number,
              issue_repository: issue_repo,
              issue_number: issue_number,
              closes_issue: true,
              created_at: Time.current,
              updated_at: Time.current
            }
          end
        end

        # Bulk insert if we have references
        if references.any?
          PullRequestIssue.upsert_all(
            references,
            unique_by: [ :pr_repository, :pr_number, :issue_repository, :issue_number ]
          )
        end
      end
    end
  end
end
