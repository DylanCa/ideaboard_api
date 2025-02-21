module Github
  class Label < T::Struct
    const :name, String
    const :color, T.nilable(String)
    const :github_repository_id, Integer

    def self.from_github(data, repo_id)
      new(
        name: data.name,
        color: data.color,
        github_repository_id: repo_id
        )
    end

    def stringify_keys
      {
        name: name,
        color: color,
        github_repository_id: github_repository_id
      }
    end
  end
end
