require_relative "../persistence/repository_persistence_service"
require_relative "../github_repository_services/orchestration_service"
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
        GithubRepositoryServices::OrchestrationService.update_repositories(repos)
      end

      def add_repo_by_name(repo_name)
        GithubRepositoryServices::OrchestrationService.add_repo_by_name(repo_name)
      end

      def fetch_repository_update(repo_name)
        RepositoryUpdateWorker.perform_async(repo_name)
      end

      def fetch_user_contributions(user)
        GithubRepositoryServices::OrchestrationService.fetch_user_contributions(user)
      end

      private

      def execute_query(query, access_token = nil, repo_name = nil, username = nil)
        response = Github::Helper.query_with_logs(query, nil, { token: access_token }, repo_name, username)

        if response.errors.any?
          LoggerExtension.log(:error, "GraphQL Query Errors", {
            errors: response.errors,
            query: query.to_s
          })
          return nil
        end

        response.data.viewer
      rescue StandardError => e
        LoggerExtension.log(:error, "Unhandled GraphQL Error", {
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(10),
          query: query.to_s
        })
        nil
      end
    end
  end
end
