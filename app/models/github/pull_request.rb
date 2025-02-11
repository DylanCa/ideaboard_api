module Github
  class PullRequest < T::Struct
    const :id, Integer
    const :html_url, String
    const :number, Integer
    const :title, String
    const :state, String
    const :repository_id, Integer
    const :repository_name, String
    const :author_username, String
    const :merged_at, T.nilable(Time)
    const :closed_at, T.nilable(Time)
    const :created_at, Time
    const :updated_at, Time
    const :draft, T::Boolean
    const :mergeable, T.nilable(T::Boolean)
    const :rebaseable, T.nilable(T::Boolean)
    const :comments, Integer
    const :review_comments, Integer
    const :commits, Integer
    const :additions, Integer
    const :deletions, Integer
    const :changed_files, Integer

    def self.from_github(data)
      new(
        id: data.id,
        html_url: data.html_url,
        number: data.number,
        title: data.title,
        state: data.state,
        repository_id: data.head.repo.id,
        repository_name: data.head.repo.full_name,
        author_username: data.user.login,
        merged_at: data.merged_at,
        closed_at: data.closed_at,
        created_at: data.created_at,
        updated_at: data.updated_at,
        draft: data.draft || false,
        mergeable: data.mergeable,
        rebaseable: data.rebaseable,
        comments: data.comments,
        review_comments: data.review_comments,
        commits: data.commits,
        additions: data.additions,
        deletions: data.deletions,
        changed_files: data.changed_files,
      )
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
