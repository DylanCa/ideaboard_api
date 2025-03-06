require 'rails_helper'

RSpec.describe GithubRepositoryServices::QueryService do
  describe '.fetch_repository' do
    let(:repo_name) { 'owner/repo' }
    let(:owner) { 'owner' }
    let(:name) { 'repo' }
    let(:mock_repository) { OpenStruct.new(name: name, owner: OpenStruct.new(login: owner)) }
    let(:mock_response) { OpenStruct.new(data: OpenStruct.new(repository: mock_repository)) }

    before do
      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
    end

    it 'fetches repository data using the GraphQL API' do
      result = described_class.fetch_repository(repo_name)

      expect(result).to eq(mock_repository)
      expect(Github::Helper).to have_received(:query_with_logs).with(
        Queries::RepositoryQueries.repository_data,
        { owner: owner, name: name },
        nil,
        repo_name,
        owner
      )
    end
  end

  describe '.fetch_items' do
    let(:repo_full_name) { 'owner/repo' }
    let(:owner) { 'owner' }
    let(:name) { 'repo' }
    let(:item_type) { :prs }
    let(:mock_nodes) { [ OpenStruct.new(title: 'PR 1'), OpenStruct.new(title: 'PR 2') ] }
    let(:mock_page_info) { OpenStruct.new(has_next_page: false, end_cursor: 'cursor') }
    let(:mock_items) { OpenStruct.new(nodes: mock_nodes, page_info: mock_page_info) }
    let(:mock_repository) { OpenStruct.new(pull_requests: mock_items) }
    let(:mock_response) { OpenStruct.new(data: OpenStruct.new(repository: mock_repository)) }

    before do
      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
    end

    context 'when fetching pull requests' do
      it 'fetches pull requests using the GraphQL API' do
        result = described_class.fetch_items(repo_full_name, item_type: :prs)

        expect(result).to eq(mock_nodes)
        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::RepositoryQueries.repository_prs,
          { owner: owner, name: name, cursor: nil },
          nil,
          repo_full_name,
          owner
        )
      end
    end

    context 'when fetching issues' do
      let(:item_type) { :issues }
      let(:mock_repository) { OpenStruct.new(issues: mock_items) }

      it 'fetches issues using the GraphQL API' do
        result = described_class.fetch_items(repo_full_name, item_type: :issues)

        expect(result).to eq(mock_nodes)
        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::RepositoryQueries.repository_issues,
          { owner: owner, name: name, cursor: nil },
          nil,
          repo_full_name,
          owner
        )
      end
    end

    context 'when pagination is required' do
      let(:mock_page_info_with_next) { OpenStruct.new(has_next_page: true, end_cursor: 'next-cursor') }
      let(:mock_page_info_final) { OpenStruct.new(has_next_page: false, end_cursor: 'final-cursor') }
      let(:mock_items_first_page) { OpenStruct.new(nodes: [ OpenStruct.new(title: 'PR 1') ], page_info: mock_page_info_with_next) }
      let(:mock_items_second_page) { OpenStruct.new(nodes: [ OpenStruct.new(title: 'PR 2') ], page_info: mock_page_info_final) }

      before do
        allow(Github::Helper).to receive(:query_with_logs).and_return(
          OpenStruct.new(data: OpenStruct.new(repository: OpenStruct.new(pull_requests: mock_items_first_page))),
          OpenStruct.new(data: OpenStruct.new(repository: OpenStruct.new(pull_requests: mock_items_second_page)))
        )
      end

      it 'fetches all pages of items' do
        result = described_class.fetch_items(repo_full_name, item_type: :prs)

        expect(result.length).to eq(2)
        expect(result.map(&:title)).to eq([ 'PR 1', 'PR 2' ])
        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::RepositoryQueries.repository_prs,
          { owner: owner, name: name, cursor: nil },
          nil,
          repo_full_name,
          owner
        )
        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::RepositoryQueries.repository_prs,
          { owner: owner, name: name, cursor: 'next-cursor' },
          nil,
          repo_full_name,
          owner
        )
      end
    end

    context 'when an error occurs' do
      before do
        allow(Github::Helper).to receive(:query_with_logs).and_raise(StandardError.new("Test error"))
        allow(LoggerExtension).to receive(:log)
      end

      it 'logs the error and returns an empty array' do
        result = described_class.fetch_items(repo_full_name, item_type: :prs)

        expect(result).to eq([])
        expect(LoggerExtension).to have_received(:log).with(
          :error,
          "Fetch prs error",
          { error_message: "Test error", repository: repo_full_name }
        )
      end
    end
  end

  describe '.fetch_updates' do
    let(:repo_full_name) { 'owner/repo' }
    let(:last_synced_at) { '2025-01-01T00:00:00Z' }
    let(:search_query) { "repo:owner/repo updated:>=2025-01-01T00:00:00Z" }
    let(:mock_nodes) { [ OpenStruct.new(title: 'Item 1') ] }
    let(:mock_search) { OpenStruct.new(nodes: mock_nodes, page_info: OpenStruct.new(has_next_page: false)) }
    let(:mock_response) { OpenStruct.new(data: OpenStruct.new(search: mock_search)) }

    before do
      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
      allow(GithubRepositoryServices::ProcessingService).to receive(:process_search_response)
    end

    it 'fetches updates using the GraphQL search API' do
      result = described_class.fetch_updates(repo_full_name, last_synced_at)

      expect(Github::Helper).to have_received(:query_with_logs).with(
        Queries::GlobalQueries.search_query,
        { query: search_query, type: "ISSUE", cursor: nil },
        repo_full_name,
        nil
      )
      expect(GithubRepositoryServices::ProcessingService).to have_received(:process_search_response).with(
        mock_nodes,
        kind_of(Hash)
      )
    end

    context 'when last_synced_at is nil' do
      it 'fetches all updates without date restriction' do
        described_class.fetch_updates(repo_full_name, nil)

        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: "repo:owner/repo", type: "ISSUE", cursor: nil },
          repo_full_name,
          nil
        )
      end
    end

    context 'when repository name is invalid' do
      it 'raises an ArgumentError' do
        expect {
          described_class.fetch_updates(nil, nil)
        }.to raise_error(ArgumentError, "repo_full_name cannot be nil")
      end
    end
  end

  describe '.fetch_user_contributions' do
    let(:username) { 'test-user' }
    let(:items) { { repositories: Set.new, prs: [], issues: [] } }
    let(:contrib_type) { :prs }
    let(:last_polled_at_date) { '2025-01-01T00:00:00Z' }
    let(:search_query) { "author:test-user is:public is:pr updated:>=2025-01-01T00:00:00Z" }
    let(:mock_nodes) { [ OpenStruct.new(title: 'Item 1') ] }
    let(:mock_search) { OpenStruct.new(nodes: mock_nodes, page_info: OpenStruct.new(has_next_page: false)) }
    let(:mock_response) { OpenStruct.new(data: OpenStruct.new(search: mock_search)) }

    before do
      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
      allow(GithubRepositoryServices::ProcessingService).to receive(:process_search_response)
    end

    it 'fetches user contributions using the GraphQL search API' do
      described_class.fetch_user_contributions(username, items, contrib_type, last_polled_at_date)

      expect(Github::Helper).to have_received(:query_with_logs).with(
        Queries::GlobalQueries.search_query,
        { query: search_query, type: "ISSUE", cursor: nil },
        nil,
        username
      )
      expect(GithubRepositoryServices::ProcessingService).to have_received(:process_search_response).with(
        mock_nodes,
        items
      )
    end

    context 'when last_polled_at_date is nil' do
      it 'fetches all contributions without date restriction' do
        described_class.fetch_user_contributions(username, items, contrib_type, nil)

        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: "author:test-user is:public is:pr", type: "ISSUE", cursor: nil },
          nil,
          username
        )
      end
    end

    context 'when contrib_type is :issues' do
      let(:contrib_type) { :issues }

      it 'uses the correct search query' do
        described_class.fetch_user_contributions(username, items, contrib_type, nil)

        expect(Github::Helper).to have_received(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: "author:test-user is:public is:issue", type: "ISSUE", cursor: nil },
          nil,
          username
        )
      end
    end
  end
end
