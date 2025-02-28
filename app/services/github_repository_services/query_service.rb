module GithubRepositoryServices
  class QueryService
    class << self
      def fetch_repository(repo_name)
        owner, name = repo_name.split("/")
        variables = { owner: owner, name: name }

        response = Github::Helper.query_with_logs(Queries::RepositoryQueries.repository_data, variables, nil, repo_name, owner)
        response.data.repository
      end

      def fetch_items(repo_full_name, item_type: :prs)
        owner, name = repo_full_name.split("/")
        query = item_type == :prs ?
                  Queries::RepositoryQueries.repository_prs :
                  Queries::RepositoryQueries.repository_issues

        items = []
        variables = { owner: owner, name: name, cursor: nil }

        loop do
          response = Github::Helper.query_with_logs(query, variables, nil, repo_full_name, owner)
          collection = item_type == :prs ?
                         response.data.repository.pull_requests :
                         response.data.repository.issues

          items.concat(collection.nodes)

          break unless collection.page_info.has_next_page
          variables[:cursor] = collection.page_info.end_cursor
        end

        items
      rescue StandardError => e
        LoggerExtension.log(:error, "Fetch #{item_type} error", {
          error_message: e.message,
          repository: repo_full_name
        })
        []
      end

      def fetch_updates(repo_full_name, last_synced_at)
        validate_update_params(repo_full_name)

        items = { repositories: Set.new, prs: [], issues: [] }
        search_query = "repo:#{repo_full_name}"
        search_query += " updated:>=#{last_synced_at}" if last_synced_at

        paginate_query(Queries::GlobalQueries.search_query, { query: search_query, type: "ISSUE" }, repo_full_name, nil) do |response|
          ProcessingService.process_search_response(response.data.search.nodes, items)
        end

        items
      end

      def fetch_user_contributions(username, items, contrib_type, last_polled_at_date = nil)
        query = Queries::GlobalQueries.search_query
        search_query = build_user_contribs_search_query(username, contrib_type, last_polled_at_date)

        paginate_query(query, { query: search_query, type: "ISSUE" }, nil, username) do |response|
          ProcessingService.process_search_response(response.data.search.nodes, items)
        end
      end

      def fetch_user_repos(username, last_polled_at_date = nil)
        query = Queries::GlobalQueries.search_query
        search_query = build_user_repos_search_query(username, last_polled_at_date)
        repos = []

        paginate_query(query, { query: search_query, type: "REPOSITORY" }, nil, username) do |response|
          repos << response.data.search.nodes
        end

        repos
      end

      private

      def paginate_query(query, initial_variables, context = {}, repo_name, username)
        variables = initial_variables.merge(cursor: nil)

        loop do
          response = Github::Helper.query_with_logs(query, variables, context, repo_name, username)
          break unless response&.data&.search

          yield(response)

          page_info = response.data.search.page_info
          break unless page_info.has_next_page

          variables[:cursor] = page_info.end_cursor
        end
      end

      def build_user_contribs_search_query(username, type, last_polled_at_date)
        type_filter = type == :prs ? "pr" : "issue"
        search_query = "author:#{username} is:public is:#{type_filter}"
        search_query += " updated:>=#{last_polled_at_date}" if last_polled_at_date

        search_query
      end

      def build_user_repos_search_query(username, last_polled_at_date)
        search_query = "owner:#{username} is:public"
        search_query += " created:>=#{last_polled_at_date}" if last_polled_at_date

        search_query
      end

      def validate_update_params(repo_full_name)
        raise ArgumentError, "repo_full_name cannot be nil" if repo_full_name.nil?
      end
    end
  end
end
