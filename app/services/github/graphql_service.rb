require_relative "../persistence/repository_persistence_service"
require_relative "../data/repository_processor_service"
require_relative "../persistence/pull_request_persistence_service"
require_relative "../persistence/issue_persistence_service"
require_relative "../../graphql/queries/user_queries"

module Github
  class GraphqlService
    class << self
      def fetch_current_user_data(user)
        query = Queries::UserQueries::UserData
        execute_query(query, user.access_token)
      end

      def fetch_current_user_repositories(user)
        query = Queries::UserQueries::UserRepositories
        data = execute_query(query, user.access_token)
        repos = data.repositories.nodes
        Services::Persistence::RepositoryPersistenceService.persist_many(repos)
      end

      def update_repositories_data
        repos = GithubRepository.all
        Services::Data::RepositoryProcessor.update_repositories(repos)
      end

      def fetch_repo_by_name(repo_name)
        Services::Data::RepositoryProcessor.fetch_repo_by_name(repo_name)
      end

      private

      def execute_query(query, access_token = nil)
        response = Client.query(query, context: { token: access_token })
        Rails.logger.info "GraphQL Response: #{response.inspect}"

        response.data.viewer if response.data
      rescue StandardError => e
        Rails.logger.error "GraphQL Error: #{e.full_message}"
        Rails.logger.error "GraphQL Error Backtrace: #{e.backtrace.join("\n")}"
        nil
      end
    end
  end
end
