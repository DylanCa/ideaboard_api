module Services
  module Data
    class RepositoryProcessor
      def self.update_repositories(repos)
        repos.each do |repo|
          items = fetch_items(repo.full_name, repo.last_synced_at_date)
          update_repository_items(repo, items)
        end
      end

      def self.fetch_repo_by_name(repo_name)
        items = fetch_items(repo_name, nil, true)
        return if items[:repos].empty?

        Services::Persistence::RepositoryPersistenceService.persist_many(items[:repos])
      end

      private

      def self.update_repository_items(repo, items)
        update_pull_requests(repo, items[:pull_requests])
        update_issues(repo, items[:issues])
        repo.update(last_synced_at: Time.current)
      end

      def self.update_pull_requests(repo, prs)
        return if prs.empty?

        Services::Persistence::PullRequestPersistenceService.persist_many(prs, repo)
      end

      def self.update_issues(repo, issues)
        return if issues.empty?

        Services::Persistence::IssuePersistenceService.persist_many(issues, repo)
      end

      def self.fetch_items(repo_full_name, last_synced_at, only_repo = false)
        items = { pull_requests: [], issues: [], repos: [] }
        cursor = nil

        query = build_search_query(repo_full_name, last_synced_at, only_repo)

        loop do
          response = execute_query(query, cursor, only_repo)
          process_response(response, items)

          page_info = response.data.search.page_info
          break unless page_info.has_next_page

          cursor = page_info.end_cursor
        end

        items
      end

      private

      def self.build_search_query(repo_full_name, last_synced_at, only_repo)
        query = "repo:#{repo_full_name}"

        if only_repo
          query += " is:PUBLIC"
        else
          query += " state:open"
        end

        if last_synced_at
          # Convert to ISO8601 format that GitHub expects
          query += " updated:>#{last_synced_at}"
        end

        query
      end

      def self.execute_query(query, cursor, only_repo)
        variables = {
          query: query,
          cursor: cursor
        }

        if only_repo
          ::Github::Client.query(::Github::Queries::UserQueries::RepositoryData, variables: variables)
        else
          ::Github::Client.query(::Github::Queries::UserQueries::RepositoriesItems, variables: variables)
        end
      end

      def self.process_response(response, items)
        response.data.search.nodes.each do |node|
          case node.__typename
          when 'PullRequest'
            items[:pull_requests] << node
          when 'Issue'
            items[:issues] << node
          when 'Repository'
            items[:repos] << node
          end
        end
      end
    end
  end
end
