module Github
  class Topic < T::Struct
    const :name, String

    def self.from_github(data)
      new(
        name: data.topic.name
      )
    end

    def stringify_keys
      {
        name: name
      }
    end
  end
end
