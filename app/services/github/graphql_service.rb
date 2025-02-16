require_relative "../persistence/repository_persistence_service"
require_relative "../processing/repository_processor_service"
require_relative "../persistence/pull_request_persistence_service"
require_relative "../persistence/issue_persistence_service"
require_relative "../../graphql/queries/user_queries"

module Github
  class GraphqlService
    class << self
      def fetch_current_user_data(user)
        query = Queries::UserQueries.user_data
        execute_query(query, user.access_token)
      end

      def fetch_current_user_repositories(user)
        query = Queries::UserQueries.user_repositories
        data = execute_query(query, user.access_token)
        repos = data.repositories.nodes
        Persistence::RepositoryPersistenceService.persist_many(repos)
      end

      def update_repositories_data
        repos = GithubRepository.all
        Processing::RepositoryProcessorService.update_repositories(repos)
      end

      def add_repo_by_name(repo_name)
        Processing::RepositoryProcessorService.add_repo_by_name(repo_name)
      end

      private

      def execute_query(query, access_token = nil)
        response = Github::Helper.query_with_logs(query, nil, { token: access_token })

        if response.errors.any?
          return nil
        end

        response.data.viewer
      rescue StandardError => e
        Rails.logger.error do
          {
            message: "Unhandled GraphQL Error",
            error: e.full_message,
            backtrace: e.backtrace.first(10),
            query: query.to_s
          }.to_json
        end

        nil
      end
    end
  end
end
