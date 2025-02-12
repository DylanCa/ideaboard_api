require_relative "../../graphql/queries/user_queries"

module Services
  module Persistence
    class RepositoryDiscoveryService
      extend T::Sig

      sig { returns(String) }
      attr_reader :access_token

      sig { returns(Set) }
      attr_reader :repository_ids

      sig { params(access_token: String).void }
      def initialize(access_token)
        @access_token = access_token
        @repository_ids = Set.new
      end

      sig { returns(T::Array[Integer]) }
      def fetch_current_user_contributions_repository_ids
        fetch_repositories
        fetch_pull_request_repositories
        fetch_issue_repositories

        repository_ids.to_a
      end

      private

      sig { void }
      def fetch_repositories
        cursor = nil

        loop do
          response = ::Github::Client.query(
            ::Github::Queries::UserQueries::UserRepositories,
            variables: { cursor: cursor },
            context: { token: access_token }
          )

          response.data.viewer.repositories.nodes.each do |repo|
            repository_ids.add(repo.id)
          end

          page_info = response.data.viewer.repositories.page_info
          break unless page_info.has_next_page

          cursor = page_info.end_cursor
        end
      end

      sig { void }
      def fetch_pull_request_repositories
        cursor = nil

        loop do
          response = ::Github::Client.query(
            ::Github::Queries::UserQueries::UserPullRequests,
            variables: { cursor: cursor },
            context: { token: access_token }
          )

          response.data.viewer.pull_requests.nodes.each do |pr|
            repository_ids.add(pr.repository.id)
          end

          page_info = response.data.viewer.pull_requests.page_info
          break unless page_info.has_next_page

          cursor = page_info.end_cursor
        end
      end

      sig { void }
      def fetch_issue_repositories
        cursor = nil

        loop do
          response = ::Github::Client.query(
            ::Github::Queries::UserQueries::UserIssues,
            variables: { cursor: cursor },
            context: { token: access_token }
          )

          response.data.viewer.issues.nodes.each do |issue|
            repository_ids.add(issue.repository.id)
          end

          page_info = response.data.viewer.issues.page_info
          break unless page_info.has_next_page

          cursor = page_info.end_cursor
        end
      end
    end
  end
end
