# config/initializers/graphql_client.rb
require "graphql/client"
require "graphql/client/http"

module Github
  class Helper
    class << self
      def query_with_logs(query, variables = nil, context = nil)
        args = {
          variables: variables,
          context: context
        }.compact

        Rails.logger.info "GraphQL Query: #{query} - Args: #{args}"

        if args.empty?
          response = Github.client.query(query)
        else
          response = Github.client.query(query, **args)
        end

        Rails.logger.info "GraphQL RateLimit: remaining #{response.data.rate_limit.remaining} - reset_at #{response.data.rate_limit.reset_at}"

        response
      end

      def installation_token
        return @token unless token_expired?

        # Get a new installation token
        jwt_client = Octokit::Client.new(bearer_token: jwt)
        installation = jwt_client.find_app_installations.first
        token_response = jwt_client.create_app_installation_access_token(installation.id)

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
        @token_expires_at - 5.minutes < Time.current
      end
    end
  end

  class << self
    def http
      @http ||= GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
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
      @client ||= GraphQL::Client.new(schema: schema, execute: http)
    end
  end
end
