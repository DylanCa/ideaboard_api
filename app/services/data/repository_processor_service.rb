module Services
  module Data
    class RepositoryProcessor
      def self.update_repositories(repos, last_polled_at_date = nil)
        repos.each do |repo|
          prs = fetch_prs(repo.full_name, last_polled_at_date)
          issues = fetch_issues(repo.full_name, last_polled_at_date)
          update_repository_items(repo, prs, issues)
        end
      end

      def self.add_repo_by_name(repo_name)
        repo = fetch_repository(repo_name)
        return if repo.nil?

        Services::Persistence::RepositoryPersistenceService.persist_many([repo])
      end

      private

      def self.fetch_repository(repo_name)
        owner, name = repo_name.split('/')
        variables = {
          owner: owner,
          name: name,
        }

        response = Github::Helper.query_with_logs(::Github::Queries::UserQueries::RepositoryData, variables)
        response.data.repository
      end

      def self.update_repository_items(repo, prs, issues)
        update_pull_requests(repo, prs)
        update_issues(repo, issues)
        repo.update(last_polled_at: Time.current)
      end

      def self.update_pull_requests(repo, prs)
        return if prs.empty?

        Services::Persistence::PullRequestPersistenceService.persist_many(prs, repo)
      end

      def self.update_issues(repo, issues)
        return if issues.empty?

        Services::Persistence::IssuePersistenceService.persist_many(issues, repo)
      end

      def self.fetch_prs(repo_full_name, last_polled_at, only_repo = false)
        owner, name = repo_full_name.split('/')
        pr_cursor = nil
        items = []


        loop do
          variables = {
            owner: owner,
            name: name,
            pr_cursor: pr_cursor,
          }

          response = Github::Helper.query_with_logs(::Github::Queries::UserQueries::RepositoryPrs, variables)
          response.data.repository.pull_requests.nodes.each {|pr| items << pr}

          pr_page_info = response.data.repository.pull_requests.page_info
          break unless pr_page_info.has_next_page

          pr_cursor = pr_page_info.end_cursor if pr_page_info.has_next_page
        end

        items
      end

      def self.fetch_issues(repo_full_name, last_polled_at, only_repo = false)
        owner, name = repo_full_name.split('/')
        issue_cursor = nil
        items = []


        loop do
          variables = {
            owner: owner,
            name: name,
            issue_cursor: issue_cursor,
          }

          response = Github::Helper.query_with_logs(::Github::Queries::UserQueries::RepositoryIssues, variables)
          response.data.repository.issues.nodes.each {|i| items << i}

          issue_page_info = response.data.repository.issues.page_info
          break unless issue_page_info.has_next_page

          issue_cursor = issue_page_info.end_cursor if issue_page_info.has_next_page
        end

        items
      end

      private

      def self.build_search_query(repo_full_name, last_polled_at, only_repo)

        query = "owner"

        if only_repo
          query += " is:PUBLIC"
        else
          query += " state:open"
        end

        if last_polled_at
          # Convert to ISO8601 format that GitHub expects
          query += " updated:>#{last_polled_at}"
        end

        query
      end

      def self.execute_query(variables, only_repo)

        if only_repo
          query = ::Github::Queries::UserQueries::RepositoryData
          Rails.logger.info "GraphQL Query: #{query} - Variables: #{variables}"

          ::Github::Client.query(query, variables: variables)
        else
          query = ::Github::Queries::UserQueries::RepositoriesItems
          Rails.logger.info "GraphQL Query: #{query} - Variables: #{variables}"

          ::Github::Client.query(query, variables: variables)
        end
      end
    end
  end
end
