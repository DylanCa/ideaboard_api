module Github
  class PullRequest < T::Struct
    const :github_id, String
    const :title, String
    const :url, String
    const :number, Integer
    const :state, String
    const :github_repository_id, Integer
    const :author_username, T.nilable(String)
    const :merged_at, T.nilable(String)
    const :closed_at, T.nilable(String)
    const :github_created_at, String
    const :github_updated_at, String
    const :is_draft, T::Boolean
    const :total_comments_count, Integer
    const :commits, Integer

    def self.from_github(data, repo_id = nil)
      new(
        github_id: data.id,
        title: data.title,
        url: data.url,
        number: data.number,
        state: data.state,
        github_repository_id: repo_id,
        author_username: data.author&.login,
        merged_at: data.merged_at,
        closed_at: data.closed_at,
        github_created_at: data.created_at,
        github_updated_at: data.updated_at,
        is_draft: data.is_draft,
        total_comments_count: data.total_comments_count,
        commits: data.commits.total_count,
      )
    end

    def self.from_array(data, repo_id = nil)
      data.map { |pr| from_github(pr, repo_id) }
    end

    def stringify_keys
      {
        github_id: github_id,
        title: title,
        url: url,
        number: number,
        state: state,
        github_repository_id: github_repository_id,
        author_username: author_username,
        merged_at: merged_at,
        closed_at: closed_at,
        github_created_at: github_created_at,
        github_updated_at: github_updated_at,
        is_draft: is_draft,
        total_comments_count: total_comments_count,
        commits: commits
      }
    end

    def open?
      state == "open"
    end

    def closed?
      state == "closed"
    end

    def merged?
      !merged_at.nil?
    end

    def draft?
      draft == true
    end

    def ready?
      !draft?
    end
  end
end
