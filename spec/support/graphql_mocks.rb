module GraphQLMocks
  def mock_github_query(query_name, fixture_file = nil)
    fixture_file ||= query_name.to_s.underscore
    fixture_path = Rails.root.join("spec/fixtures/github_api/#{fixture_file}.json")

    raise "Fixture not found: #{fixture_path}" unless File.exist?(fixture_path)

    deep_ostruct_from_hash = lambda do |obj|
      case obj
      when Hash
        OpenStruct.new(obj.transform_values(&deep_ostruct_from_hash))
      when Array
        obj.map(&deep_ostruct_from_hash)
      else
        obj
      end
    end

    raw_mock_response = JSON.parse(File.read(fixture_path))
    mock_response = deep_transform_keys(raw_mock_response)

    mock_response_obj = OpenStruct.new(
      data: deep_ostruct_from_hash.call(mock_response),
      errors: nil
    )

    mock_client = double('GraphQL::Client',
                         query: mock_response_obj
    )

    allow(mock_client).to receive(:parse).and_return(double('GraphQL::Client::OperationDefinition'))
    allow(Github).to receive(:client).and_return(mock_client)
    mock_response_obj
  end

  def mock_github_query_with_variables(query_name, variables, fixture_file = nil)
    fixture_file ||= query_name.to_s.underscore
    fixture_path = Rails.root.join("spec/fixtures/github_api/#{fixture_file}.json")

    raise "Fixture not found: #{fixture_path}" unless File.exist?(fixture_path)

    deep_ostruct_from_hash = lambda do |obj|
      case obj
      when Hash
        OpenStruct.new(obj.transform_values(&deep_ostruct_from_hash))
      when Array
        obj.map(&deep_ostruct_from_hash)
      else
        obj
      end
    end

    raw_mock_response = JSON.parse(File.read(fixture_path))
    mock_response = deep_transform_keys(raw_mock_response)

    mock_response_obj = OpenStruct.new(
      data: deep_ostruct_from_hash.call(mock_response),
      errors: nil
    )

    # Create a more complete double that handles both query and parse methods
    mock_client = double('GraphQL::Client')
    allow(mock_client).to receive(:query).and_return(mock_response_obj)
    allow(mock_client).to receive(:query).with(
      any_args,
      hash_including(variables: variables)
    ).and_return(mock_response_obj)

    allow(mock_client).to receive(:parse).and_return(double('GraphQL::Client::OperationDefinition'))
    allow(Github).to receive(:client).and_return(mock_client)
    mock_response_obj
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
end

RSpec.configure do |config|
  config.include GraphQLMocks
end
