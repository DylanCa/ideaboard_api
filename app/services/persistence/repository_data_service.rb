require_relative "../../graphql/queries/user_queries"

module Services
  module Persistence
    class RepositoryDataService
      extend T::Sig

      sig { params(repository: GithubRepository).void }
      def initialize(repository)
        @repository = repository
      end

      def fetch_all_open_items(last_synced_at = nil)
        items = { pull_requests: [], issues: [] }
        cursor = nil

        query = build_search_query(last_synced_at)

        loop do
          response = execute_query(query, cursor)
          process_response(response, items)

          page_info = response.data.search.page_info
          break unless page_info.has_next_page

          cursor = page_info.end_cursor
        end

        items
      end

      private

      def build_search_query(last_synced_at)
        query = "repo:#{@repository.full_name} state:open"

        if last_synced_at
          # Convert to ISO8601 format that GitHub expects
          timestamp = last_synced_at.iso8601
          query += " updated:>#{timestamp}"
        end

        query
      end

      def execute_query(query, cursor)
        variables = {
          query: query,
          cursor: cursor
        }

        ::Github::Client.query(::Github::Queries::UserQueries::RepositoriesData, variables: variables)
      end

      def process_response(response, items)
        response.data.search.nodes.each do |node|
          case node.__typename
          when 'PullRequest'
            items[:pull_requests] << Github::PullRequest.from_github(node, @repository.id)
          when 'Issue'
            items[:issues] << Github::Issue.from_github(node, @repository.id)
          end
        end
      end
    end

    class RepositoryProcessor
      def self.update_all_repositories
        repos = GithubRepository.all

        repos.each do |repo|
          updater = RepositoryDataService.new(repo)
          items = updater.fetch_all_open_items
          update_repository_items(repo, items)
          repo.update(updated_at: Time.current)
        end
      end

      private

      def self.update_repository_items(repo, items)
        ApplicationRecord.transaction do
          update_pull_requests(repo, items[:pull_requests])
          update_issues(repo, items[:issues])
        end
      end

      def self.update_pull_requests(repo, prs)
        return if prs.empty?

        repo.pull_requests.upsert_all(
          prs.map(&:stringify_keys),
          returning: false
        )
      end

      def self.update_issues(repo, issues)
        return if issues.empty?

        repo.issues.upsert_all(
          issues.map(&:stringify_keys),
          returning: false
        )
      end
    end
  end
end