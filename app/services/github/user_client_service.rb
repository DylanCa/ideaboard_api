module Github
  class UserClientService
    def initialize(user)
      access_token = user.access_token
      @client = Octokit::Client.new(access_token: access_token)
      @username = user.github_account.github_username
    end

    def get_repo_prs(repo_name)
      prs = @client.pulls(repo_name)
      if prs.incomplete_results
        # TODO: consider usecase
        raise Error
      end

      prs.items.map do |pr|
        actual_pr = pr.pull_request.rels[:self].get.data
        Github::PullRequest.from_github(actual_pr)
      end.compact
    end

    def public_repositories
      repos = @client.repositories(nil, { type: "public" })
      repos.map { |repo| Github::Repository.from_github(repo) }
    end

    def issues
      issues = @client.search_issues("sort:updated-desc is:issue author:@me archived:false is:public")
      if issues.incomplete_results
        # TODO: consider usecase
        raise Error
      end

      issues.items.map do |issue|
        actual_issue = issue.rels[:self].get.data
        Github::PullRequest.from_github(actual_issue)
      end.compact
    end

    def pull_requests
      prs = @client.pulls
      if prs.incomplete_results
        # TODO: consider usecase
        raise Error
      end

      prs.items.map do |pr|
        actual_pr = pr.pull_request.rels[:self].get.data
        Github::PullRequest.from_github(actual_pr)
      end.compact
    end
  end
end
