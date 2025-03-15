module Github
  class Repository < T::Struct
    const :github_id, String
    const :author_username, T.nilable(String)
    const :full_name, String
    const :description, T.nilable(String)
    const :language, T.nilable(String)
    const :is_fork, T::Boolean
    const :stars_count, Integer
    const :forks_count, Integer
    const :archived, T::Boolean
    const :disabled, T::Boolean
    const :visible, T::Boolean
    const :license, T.nilable(String)
    const :github_created_at, String
    const :github_updated_at, String
    const :has_contributing, T::Boolean
    const :contributing_guidelines, T.nilable(String)
    const :contributing_url, T.nilable(String)

    def self.from_github(data)
      new(
        github_id: data.id,
        author_username: data.owner.login,
        full_name: data.name_with_owner,
        description: data.description,
        language: data.primary_language&.name&.downcase,
        is_fork: data.is_fork,
        stars_count: data.stargazer_count,
        forks_count: data.fork_count,
        archived: data.is_archived,
        disabled: data.is_disabled,
        visible: true,
        license: data.license_info&.key,
        github_created_at: data.created_at,
        github_updated_at: data.updated_at,
        has_contributing: !data.contributing_guidelines.nil?,
        contributing_guidelines: data.contributing_guidelines&.body,
        contributing_url: data.contributing_guidelines&.url,
        )
    end

    def stringify_keys
      {
        github_id: github_id,
        author_username: author_username,
        full_name: full_name,
        description: description,
        language: language,
        is_fork: is_fork,
        stars_count: stars_count,
        forks_count: forks_count,
        archived: archived,
        disabled: disabled,
        license: license,
        visible: visible,
        github_created_at: github_created_at,
        github_updated_at: github_updated_at,
        has_contributing: has_contributing,
        contributing_guidelines: contributing_guidelines,
        contributing_url: contributing_url
      }
    end
  end
end
