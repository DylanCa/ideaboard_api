module GithubRepositoryServices
  class SpecificItemFetcherService
    class << self
      def fetch_pull_request(repo_name, pr_number)
        owner, name = repo_name.split("/")
        variables = { owner: owner, name: name, number: pr_number }

        response = Github::Helper.query_with_logs(
          Queries::ItemQueries.specific_pull_request,
          variables
        )

        return nil unless response&.data&.repository&.pull_request

        [ response.data.repository.pull_request ]
      rescue StandardError => e
        LoggerExtension.log(:error, "Error fetching specific PR", {
          repo: repo_name,
          number: pr_number,
          error: e.message
        })
        nil
      end

      def fetch_issue(repo_name, issue_number)
        owner, name = repo_name.split("/")
        variables = { owner: owner, name: name, number: issue_number }

        response = Github::Helper.query_with_logs(
          Queries::ItemQueries.specific_issue,
          variables
        )

        return nil unless response&.data&.repository&.issue

        [ response.data.repository.issue ]
      rescue StandardError => e
        LoggerExtension.log(:error, "Error fetching specific Issue", {
          repo: repo_name,
          number: issue_number,
          error: e.message
        })
        nil
      end
    end
  end
end
