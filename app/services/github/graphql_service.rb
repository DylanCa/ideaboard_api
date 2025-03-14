require_relative "../persistence/repository_persistence_service"
require_relative "../../graphql/queries/user_queries"

module Github
  class GraphqlService
    class << self
      def fetch_current_user_data(user)
        query = Queries::UserQueries.user_data
        execute_query(query, user.access_token)
      end

      def fetch_current_user_repositories(user)
        UserRepositoriesFetcherWorker.perform_async(user.id)
      end

      def update_repositories_data
        repos = GithubRepository.all
        repos.each do |repo|
          RepositoryDataFetcherWorker.perform_async(repo.full_name)
        end
      end

      def add_repo_by_name(repo_name)
        RepositoryDataFetcherWorker.perform_async(repo_name)
      end

      def fetch_repository_update(repo_name)
        RepositoryUpdateWorker.perform_async(repo_name)
      end

      def fetch_user_contributions(user)
        UserContributionsFetcherWorker.perform_async(user.id)
      end

      private

      def execute_query(query, access_token = nil, repo_name = nil, username = nil)
        response = Github::Helper.query_with_logs(query, nil, { token: access_token }, repo_name, username)

        return response.data.viewer unless response.errors&.any?

        LoggerExtension.log(:error, "GraphQL Query Errors", {
          errors: response.errors,
          query: query.to_s
        })

        nil
      rescue StandardError => e
        LoggerExtension.log(:error, "Unhandled GraphQL Error", {
          class: e.class.name,
          message: e.message,
          backtrace: e.backtrace.first(10),
          query: query.to_s
        })
        nil
      end
    end
  end
end
