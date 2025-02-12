module Github
  class Helpers
    class << self
      def extract_pull_requests(data)
        data.pull_requests.total_count > 0 ? PullRequest.from_array(data.pull_requests.nodes, data.database_id) : nil
      rescue GraphQL::Client::UnfetchedFieldError
        nil
      end

      def extract_issues(data)
        data.issues.total_count > 0 ? Issue.from_array(data.issues.nodes, data.database_id) : nil
      rescue GraphQL::Client::UnfetchedFieldError
        nil
      end
    end
  end
end
