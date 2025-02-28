require_relative "./graphql_execution_service"
require_relative "./token_selection_service"

module Github
  class Helper
    class << self
      def query_with_logs(query, variables = nil, context = nil, repo_name = nil, username = nil)
        GraphQLExecutionService.execute_query(query, variables, context, repo_name, username)
      end

      def installation_token
        TokenSelectionService.installation_token
      end
    end
  end
end
