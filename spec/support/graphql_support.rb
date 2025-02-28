module GraphQLSupport
  def stub_github_graphql_query(query_name, fixture_data = {})
    # Ensure rate_limit is always an object with the required methods
    default_rate_limit = {
      cost: 1,
      remaining: 4999,
      reset_at: Time.current.to_s,
      limit: 5000,
      used: 1
    }

    # Merge default rate limit with any provided rate limit data
    fixture_data[:rate_limit] = default_rate_limit.merge(fixture_data[:rate_limit] || {})

    # Convert nested hashes to OpenStruct for method-like access
    deep_ostruct_from_hash = lambda do |obj|
      if obj.is_a?(Hash)
        OpenStruct.new(obj.transform_values(&deep_ostruct_from_hash))
      elsif obj.is_a?(Array)
        obj.map(&deep_ostruct_from_hash)
      else
        obj
      end
    end

    # Create a mock response object that mimics GraphQL::Client::Response
    mock_response = double('GraphQL::Client::Response',
                           data: deep_ostruct_from_hash.call(fixture_data),
                           errors: nil
    )

    # Stub the entire Github.client method to return a mock client
    mock_client = double('GraphQL::Client',
                         query: mock_response
    )

    # Stub the class-level methods
    allow(Github).to receive(:client).and_return(mock_client)

    # Create a mock viewer object for logging purposes
    allow(mock_response.data).to receive(:viewer).and_return(
      OpenStruct.new(fixture_data.dig(:viewer))
    )

    # Return the mock response in case you want to do additional assertions
    mock_response
  end
end

RSpec.configure do |config|
  config.include GraphQLSupport
end
