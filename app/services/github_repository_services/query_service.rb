module GithubRepositoryServices
  class QueryService
    class << self
      def fetch_repository(repo_name)
        owner, name = repo_name.split("/")
        variables = { owner: owner, name: name }

        response = Github::Helper.query_with_logs(Queries::UserQueries.repository_data, variables)
        response.data.repository
      end

      def fetch_items(repo_full_name, item_type: :prs)
        owner, name = repo_full_name.split("/")
        query = item_type == :prs ?
                  Queries::UserQueries.repository_prs :
                  Queries::UserQueries.repository_issues

        items = []
        variables = { owner: owner, name: name, cursor: nil }

        loop do
          response = Github::Helper.query_with_logs(query, variables)
          collection = item_type == :prs ?
                         response.data.repository.pull_requests :
                         response.data.repository.issues

          items.concat(collection.nodes)

          break unless collection.page_info.has_next_page
          variables[:cursor] = collection.page_info.end_cursor
        end

        items
      rescue StandardError => e
        Rails.logger.error "Fetch #{item_type} error: #{e.message}"
        []
      end

      def fetch_updates(repo_full_name, last_synced_at)
        validate_update_params(repo_full_name)

        items = { prs: [], issues: [] }
        search_query = "repo:#{repo_full_name}"
        search_query += " updated:>=#{last_synced_at}" if last_synced_at

        paginate_query(Queries::UserQueries.search_query, { query: search_query }) do |response|
          ProcessingService.process_search_response(response.data.search.nodes, items)
        end

        items
      end

      def fetch_user_contribution_type(user, items, contrib_type)
        query = Queries::UserQueries.search_query
        search_query = build_user_search_query(user.github_account.github_username, contrib_type)

        paginate_query(query, { query: search_query }) do |response|
          ProcessingService.process_search_response(response.data.search.nodes, items)
        end
      end

      private

      def paginate_query(query, initial_variables, context = {})
        variables = initial_variables.merge(cursor: nil)

        loop do
          response = Github::Helper.query_with_logs(query, variables, context)
          break unless response&.data&.search

          yield(response)

          page_info = response.data.search.page_info
          break unless page_info.has_next_page

          variables[:cursor] = page_info.end_cursor
        end
      end

      def build_user_search_query(username, type)
        type_filter = type == :prs ? 'pr' : 'issue'
        "author:#{username} is:public is:#{type_filter}"
      end

      def validate_update_params(repo_full_name)
        raise ArgumentError, "repo_full_name cannot be nil" if repo_full_name.nil?
      end
    end
  end
end