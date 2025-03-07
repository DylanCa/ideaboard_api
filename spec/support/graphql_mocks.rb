module GraphQLMocks
  def mock_github_query(query_name, fixture_file = nil)
    fixture_file ||= query_name.to_s.underscore
    fixture_path = Rails.root.join("spec/fixtures/github_api/#{fixture_file}.json")

    raise "Fixture not found: #{fixture_path}" unless File.exist?(fixture_path)

    # Create response from fixture
    response = create_response_from_fixture(fixture_path)

    # Create an isolated double for this specific test
    mock_operation = double("GraphQL::Client::OperationDefinition_#{Time.now.to_i}_#{rand(1000)}")
    mock_client = double("GraphQL::Client_#{Time.now.to_i}_#{rand(1000)}")

    # Set up the doubles
    allow(mock_client).to receive(:parse).and_return(mock_operation)
    allow(mock_client).to receive(:query).and_return(response)

    # Apply the mock for this test
    allow(Github).to receive(:client).and_return(mock_client)

    # Important: stub the actual query objects
    stub_repository_queries
    stub_global_queries

    response
  end

  def mock_github_query_with_variables(query_name, variables, fixture_file = nil)
    # Similar setup as above but handle variables
    response = mock_github_query(query_name, fixture_file)

    # Get the last mock client that was set up
    mock_client = Github.client

    # Add variable-specific behavior
    allow(mock_client).to receive(:query).with(
      anything,
      hash_including(variables: variables)
    ).and_return(response)

    response
  end

  def reset_graphql_client
    # Create unique doubles
    mock_operation = double("GraphQL::Client::OperationDefinition_#{Time.now.to_i}_#{rand(1000)}")
    mock_client = double("GraphQL::Client_#{Time.now.to_i}_#{rand(1000)}")

    # Set up the doubles
    allow(mock_client).to receive(:parse).and_return(mock_operation)
    allow(mock_client).to receive(:query).and_return(nil)

    # Apply the mock
    allow(Github).to receive(:client).and_return(mock_client)

    # Stub the query definitions
    stub_repository_queries
    stub_global_queries
  end

  private

  def create_response_from_fixture(fixture_path)
    raw_data = JSON.parse(File.read(fixture_path))
    transformed = deep_transform_keys(raw_data)

    # Convert to nested OpenStructs
    data_ostruct = to_ostruct(transformed)

    OpenStruct.new(data: data_ostruct, errors: nil)
  end

  def to_ostruct(obj)
    case obj
    when Hash
      OpenStruct.new(obj.transform_values { |v| to_ostruct(v) })
    when Array
      obj.map { |v| to_ostruct(v) }
    else
      obj
    end
  end

  def deep_transform_keys(obj)
    case obj
    when Hash
      obj.transform_keys { |key| key.to_s.underscore.to_sym }
         .transform_values { |val| deep_transform_keys(val) }
    when Array
      obj.map { |val| deep_transform_keys(val) }
    else
      obj
    end
  end

  # Stub all query definition methods to return new doubles each time
  def stub_repository_queries
    # Stub repository query definitions
    repo_data = double("RepositoryData_#{Time.now.to_i}_#{rand(1000)}")
    repo_prs = double("RepositoryPrs_#{Time.now.to_i}_#{rand(1000)}")
    repo_issues = double("RepositoryIssues_#{Time.now.to_i}_#{rand(1000)}")

    allow(Queries::RepositoryQueries).to receive(:repository_data).and_return(repo_data)
    allow(Queries::RepositoryQueries).to receive(:repository_prs).and_return(repo_prs)
    allow(Queries::RepositoryQueries).to receive(:repository_issues).and_return(repo_issues)
  end

  def stub_global_queries
    # Stub global query definitions
    search_query = double("SearchQuery_#{Time.now.to_i}_#{rand(1000)}")
    allow(Queries::GlobalQueries).to receive(:search_query).and_return(search_query)
  end
end

RSpec.configure do |config|
  config.include GraphQLMocks

  # Reset all test doubles after each test
  config.after(:each) do
    RSpec::Mocks.space.reset_all
  end
end
