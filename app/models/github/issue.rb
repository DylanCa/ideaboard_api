module Github
  class Issue < T::Struct
    const :full_database_id, Integer
    const :title, String
    const :url, String
    const :number, Integer
    const :state, String
    const :repository_id, Integer
    const :author_username, T.nilable(String)
    const :comments_count, Integer
    const :reactions_count, Integer
    const :created_at, String
    const :updated_at, String
    const :closed_at, T.nilable(String) # can be nil

    def self.from_github(data, repo_id = nil)
      new(
        full_database_id: data.full_database_id.to_i,
        title: data.title,
        url: data.url,
        number: data.number,
        state: data.state,
        repository_id: repo_id || data.repository.database_id,
        author_username: data.author&.login,
        comments_count: data.comments.total_count,
        reactions_count: data.reactions.total_count,
        created_at: data.created_at,
        updated_at: data.updated_at,
        closed_at: data.closed_at
      )
    end

    def self.from_array(data, repo_id = nil)
      data.map { |i| from_github(i, repo_id) }
    end

    def open?
      state == "open"
    end

    def closed?
      !open?
    end

    private

    def self.parse_reactions(reactions)
      return 0 unless reactions
      %i[plus1 minus1 laugh hooray confused heart rocket eyes].sum do |type|
        reactions[type].to_i
      end
    end
  end
end
