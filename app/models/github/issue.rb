module Github
  class Issue < T::Struct
    const :github_id, String
    const :title, String
    const :url, String
    const :number, Integer
    const :github_repository_id, Integer
    const :author_username, T.nilable(String)
    const :comments_count, Integer
    const :github_created_at, String
    const :github_updated_at, String
    const :closed_at, T.nilable(String)

    def self.from_github(data, repo_id = nil)
      new(
        github_id: data.id,
        title: data.title,
        url: data.url,
        number: data.number,
        github_repository_id: repo_id,
        author_username: data.author&.login,
        comments_count: data.comments.total_count,
        github_created_at: data.created_at,
        github_updated_at: data.updated_at,
        closed_at: data.closed_at
      )
    end

    def self.from_array(data, repo_id = nil)
      data.map { |i| from_github(i, repo_id) }
    end

    def stringify_keys
      {
        github_id: github_id,
        title: title,
        url: url,
        number: number,
        github_repository_id: github_repository_id,
        author_username: author_username,
        comments_count: comments_count,
        github_created_at: github_created_at,
        github_updated_at: github_updated_at,
        closed_at: closed_at
      }
    end
  end
end
