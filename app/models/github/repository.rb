module Github
  class Repository < T::Struct
    const :id, Integer
    const :name, String
    const :full_name, String
    const :description, T.nilable(String)
    const :language, T.nilable(String)
    const :fork, T::Boolean
    const :stars_count, Integer
    const :forks_count, Integer
    const :open_issues_count, Integer
    const :archived, T::Boolean
    const :disabled, T::Boolean
    const :license, T.nilable(String)
    const :created_at, Time
    const :updated_at, Time

    def self.from_github(data)
      new(
        id: data.id,
        name: data.name,
        full_name: data.full_name,
        description: data.description,
        language: data.language,
        fork: data.fork,
        stars_count: data.stargazers_count,
        forks_count: data.forks_count,
        open_issues_count: data.open_issues_count,
        archived: data.archived,
        disabled: data.disabled,
        license: data.license&.key,
        created_at: data.created_at,
        updated_at: data.updated_at
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
