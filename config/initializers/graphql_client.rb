require "graphql/client"
require "graphql/client/http"

module Github
  class << self
    def http
      GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
        def headers(context)
          token = context[:token]
          token ||= Github::Helper.installation_token

          {
            "Authorization" => "Bearer #{token}"
          }
        end
      end
    end

    def schema
      @schema ||= if File.exist?(Rails.root.join("app/graphql/schema.json"))
                    GraphQL::Client.load_schema("app/graphql/schema.json")
      else
                    new_schema = GraphQL::Client.load_schema(http)
                    schema_path = Rails.root.join("app/graphql/schema.json")
                    FileUtils.mkdir_p(File.dirname(schema_path))
                    File.write(schema_path, JSON.pretty_generate(GraphQL::Client.dump_schema(new_schema)))
                    new_schema
      end
    end

    def client
      GraphQL::Client.new(schema: schema, execute: http)
    end
  end
end
