module Github
  class Repository < T::Struct
    const :github_id, Integer
    const :name, String
    const :name_with_owner, String
    const :pull_requests, T.nilable(T::Array[PullRequest])
    const :issues, T.nilable(T::Array[Issue])
    const :description, T.nilable(String)
    const :primary_language, T.nilable(String)
    const :is_fork, T::Boolean
    const :stars_count, Integer
    const :forks_count, Integer
    const :total_commits_count, Integer
    const :archived, T::Boolean
    const :disabled, T::Boolean
    const :license, T.nilable(String)
    const :github_created_at, String
    const :github_updated_at, String

    def self.from_github(data)
      new(
        github_id: data.database_id,
        name: data.name,
        name_with_owner: data.name_with_owner,
        pull_requests: Helpers.extract_pull_requests(data),
        issues: Helpers.extract_issues(data),
        description: data.description,
        primary_language: data.primary_language&.name,
        is_fork: data.is_fork,
        stars_count: data.stargazer_count,
        forks_count: data.fork_count,
        archived: data.is_archived,
        disabled: data.is_disabled,
        license: data.license_info&.key,
        github_created_at: data.created_at,
        github_updated_at: data.updated_at,
        total_commits_count: data.default_branch_ref&.target&.history&.total_count || 0,
      )
    end

    def license?
      !license.nil?
    end

    def active?
      !archived && !disabled
    end
  end
end
