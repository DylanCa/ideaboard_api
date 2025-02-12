require_relative '../persistence/repository_persistence_service'
require_relative '../persistence/repository_discovery_service'
require_relative '../persistence/repository_data_service'
require_relative '../persistence/pull_request_persistence_service'
require_relative '../persistence/issue_persistence_service'
require_relative '../../graphql/queries/user_queries'

module Github
  class GraphqlService
    class << self
      def fetch_current_user_data(user)
        query = Queries::UserQueries::UserData
        execute_query(query, user.access_token)
      end

      def fetch_current_user_repositories(user)
        query = Queries::UserQueries::UserRepositoriesData
        data = execute_query(query, user.access_token)
        repos = data.repositories.nodes.map { |repo| Github::Repository.from_github(repo) }
        Services::Persistence::RepositoryPersistenceService.persist_many(repos, user.id)

        repos
      end

      def fetch_current_user_prs(user)
        query = Queries::UserQueries::UserPRsData
        data = execute_query(query, user.access_token)
        prs = data.pull_requests.nodes.map { |pr| Github::PullRequest.from_github(pr) }
        Services::Persistence::PullRequestPersistenceService.persist_many(prs)

        prs
      end

      def fetch_current_user_issues(user)
        query = Queries::UserQueries::UserIssuesData
        data = execute_query(query, user.access_token)
        issues = data.issues.nodes.map { |issue| Github::Issue.from_github(issue) }
        Services::Persistence::IssuePersistenceService.persist_many(issues, user.id)

        issues
      end

      def fetch_current_user_contributions(user)
        service = Services::Persistence::RepositoryDiscoveryService.new(user.access_token)
        repository_ids = service.fetch_current_user_contributions_repository_ids

        service = Services::Persistence::RepositoryDataService.new(user.id, user.access_token)
        service.fetch_and_persist_repositories_data(repository_ids)
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
