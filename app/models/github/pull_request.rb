module Github
  class PullRequest < T::Struct
    const :full_database_id, Integer
    const :title, String
    const :url, String
    const :number, Integer
    const :state, String
    const :repository_id, Integer
    const :author_username, T.nilable(String)
    const :merged_at, T.nilable(String)
    const :closed_at, T.nilable(String)
    const :created_at, String
    const :updated_at, String
    const :is_draft, T::Boolean
    const :mergeable, T.nilable(String)
    const :can_be_rebased, T.nilable(T::Boolean)
    const :total_comments_count, Integer
    const :commits, Integer
    const :additions, Integer
    const :deletions, Integer
    const :changed_files, Integer

    def self.from_github(data, repo_id = nil)
      new(
        full_database_id: data.full_database_id.to_i,
        title: data.title,
        url: data.url,
        number: data.number,
        state: data.state,
        repository_id: repo_id || data.repository.database_id,
        author_username: data.author&.login,
        merged_at: data.merged_at,
        closed_at: data.closed_at,
        created_at: data.created_at,
        updated_at: data.updated_at,
        is_draft: data.is_draft,
        mergeable: data.mergeable,
        can_be_rebased: data.can_be_rebased,
        total_comments_count: data.total_comments_count,
        commits: data.commits.total_count,
        additions: data.additions,
        deletions: data.deletions,
        changed_files: data.changed_files,
      )
    end

    def self.from_array(data, repo_id = nil)
      data.map { |pr| from_github(pr, repo_id) }
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
