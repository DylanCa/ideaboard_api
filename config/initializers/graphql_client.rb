require "graphql/client"
require "graphql/client/http"

module Github
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      token = context[:token]
      token ||= token = Helper.installation_token

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

  class Helper
    class << self
      def query_with_logs(query, variables)
        Rails.logger.info "GraphQL Query: #{query} - Variables: #{variables}"
        response = Client.query(query, variables: variables)
        Rails.logger.info "GraphQL RateLimit: remaining #{response.data.rate_limit.remaining} - reset_at #{response.data.rate_limit.reset_at}"

        response
      end
      def installation_token
        return @token unless token_expired?

        # Get a new installation token
        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

        # The expires_at might already be a Time object
        @token_expires_at = token_response[:expires_at]
        @token = token_response[:token]
      end

      private

      def jwt
        private_key = OpenSSL::PKey::RSA.new(ENV["GITHUB_APP_PRIVATE_KEY"])
        payload = {
          iat: Time.now.to_i - 60,
          exp: Time.now.to_i + (10 * 60),
          iss: ENV["GITHUB_APP_CLIENT_ID"]
        }

        JWT.encode(payload, private_key, "RS256")
      end

      def token_expired?
        return true if @token_expires_at.nil?
        # Add some buffer (say 5 minutes) to ensure we refresh before actual expiration
        @token_expires_at - 5.minutes < Time.current
      end
    end
  end
end
