require "graphql/client"
require "graphql/client/http"
require_relative "../../app/services/github/app_client_service"


module Github
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      token = context[:token]
      token ||= token = Github::AppClientService.installation_token

      {
        "Authorization" => "Bearer #{token}"
      }
    end
  end

  if File.exist?(Rails.root.join("app/graphql/schema.json"))
    Schema = GraphQL::Client.load_schema("app/graphql/schema.json")
  else
    Schema = GraphQL::Client.load_schema(HTTP)

    schema_path = Rails.root.join("app/graphql/schema.json")
    File.write(schema_path, JSON.pretty_generate(GraphQL::Client.dump_schema(Schema)))
    puts "Github GraphQL Schema dumped to: #{schema_path}"
  end

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
