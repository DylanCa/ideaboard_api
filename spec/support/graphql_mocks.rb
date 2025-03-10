module GraphQLMocks
  def mock_github_query(query_name, fixture_file = nil)
    fixture_file ||= query_name.to_s.underscore
    fixture_path = Rails.root.join("spec/fixtures/github_api/#{fixture_file}.json")

    raise "Fixture not found: #{fixture_path}" unless File.exist?(fixture_path)

    response = create_response_from_fixture(fixture_path)

    mock_operation = double("GraphQL::Client::OperationDefinition_#{Time.now.to_i}_#{rand(1000)}")
    mock_client = double("GraphQL::Client_#{Time.now.to_i}_#{rand(1000)}")

    allow(mock_client).to receive(:parse).and_return(mock_operation)
    allow(mock_client).to receive(:query).and_return(response)

    allow(Github).to receive(:client).and_return(mock_client)

    stub_repository_queries
    stub_global_queries

    response
  end

  def mock_github_query_with_variables(query_name, variables, fixture_file = nil)
    response = mock_github_query(query_name, fixture_file)

    mock_client = Github.client

    allow(mock_client).to receive(:query).with(
      anything,
      hash_including(variables: variables)
    ).and_return(response)

    response
  end

  def reset_graphql_client
    mock_operation = double("GraphQL::Client::OperationDefinition_#{Time.now.to_i}_#{rand(1000)}")
    mock_client = double("GraphQL::Client_#{Time.now.to_i}_#{rand(1000)}")

    allow(mock_client).to receive(:parse).and_return(mock_operation)
    allow(mock_client).to receive(:query).and_return(nil)

    allow(Github).to receive(:client).and_return(mock_client)

    stub_repository_queries
    stub_global_queries
  end

  private

  def create_response_from_fixture(fixture_path)
    raw_data = JSON.parse(File.read(fixture_path))
    transformed = deep_transform_keys(raw_data)

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

  def stub_repository_queries
    repo_data = double("RepositoryData_#{Time.now.to_i}_#{rand(1000)}")
    repo_prs = double("RepositoryPrs_#{Time.now.to_i}_#{rand(1000)}")
    repo_issues = double("RepositoryIssues_#{Time.now.to_i}_#{rand(1000)}")

    allow(Queries::RepositoryQueries).to receive(:repository_data).and_return(repo_data)
    allow(Queries::RepositoryQueries).to receive(:repository_prs).and_return(repo_prs)
    allow(Queries::RepositoryQueries).to receive(:repository_issues).and_return(repo_issues)
  end

  def stub_global_queries
    search_query = double("SearchQuery_#{Time.now.to_i}_#{rand(1000)}")
    allow(Queries::GlobalQueries).to receive(:search_query).and_return(search_query)
  end
end

RSpec.configure do |config|
  config.include GraphQLMocks

  config.after(:each) do
    RSpec::Mocks.space.reset_all
  end
end
