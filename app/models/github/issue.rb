module Github
  class Issue < T::Struct
    const :id, Integer
    const :number, Integer
    const :title, String
    const :state, String
    const :repository_id, Integer
    const :repository_name, String
    const :author_username, String
    const :comments_count, Integer
    const :reactions, Integer
    const :created_at, Time
    const :updated_at, Time
    const :closed_at, T.nilable(Time) # can be nil

    def self.from_github(data)
      new(
        id: data.id,
        number: data.number,
        title: data.title,
        state: data.state,
        repository_id: data.repository.id,
        repository_name: data.repository.full_name,
        author_username: data.user.login,
        comments_count: data.comments,
        reactions: parse_reactions(data.reactions),
        created_at: data.created_at,
        updated_at: data.updated_at,
        closed_at: data.closed_at
      )
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
