require 'rails_helper'

RSpec.describe GithubRepositoryServices::QueryService do
  describe '.fetch_repository' do
    let(:repo_name) { 'owner/repo' }
    let(:owner) { 'owner' }
    let(:name) { 'repo' }

    it 'fetches repository data using the GraphQL API' do
      mock_response = mock_github_query_with_variables(
        'repository_data',
        { owner: owner, name: name },
        'repository_data'
      )

      expect(Github::Helper).to receive(:query_with_logs).with(
        Queries::RepositoryQueries.repository_data,
        { owner: owner, name: name },
        nil,
        repo_name,
        owner
      ).and_return(mock_response)

      result = described_class.fetch_repository(repo_name)

      expect(result).to eq(mock_response.data.repository)
    end
  end

  describe '.fetch_items' do
    let(:repo_full_name) { 'owner/repo' }
    let(:owner) { 'owner' }
    let(:name) { 'repo' }

    context 'when fetching pull requests' do
      it 'fetches pull requests using the GraphQL API' do
        mock_response = mock_github_query_with_variables(
          'repository_prs',
          { owner: owner, name: name, cursor: nil },
          'repository_prs'
        )

        expect(Github::Helper).to receive(:query_with_logs).with(
          Queries::RepositoryQueries.repository_prs,
          { owner: owner, name: name, cursor: nil },
          nil,
          repo_full_name,
          owner
        ).and_return(mock_response)

        result = described_class.fetch_items(repo_full_name, item_type: :prs)

        expect(result).to eq(mock_response.data.repository.pull_requests.nodes)
      end
    end

    context 'when fetching issues' do
      it 'fetches issues using the GraphQL API' do
        mock_response = mock_github_query_with_variables(
          'repository_issues',
          { owner: owner, name: name, cursor: nil },
          'repository_issues'
        )

        expect(Github::Helper).to receive(:query_with_logs).with(
          Queries::RepositoryQueries.repository_issues,
          { owner: owner, name: name, cursor: nil },
          nil,
          repo_full_name,
          owner
        ).and_return(mock_response)

        result = described_class.fetch_items(repo_full_name, item_type: :issues)

        expect(result).to eq(mock_response.data.repository.issues.nodes)
      end
    end

    context 'when an error occurs' do
      it 'logs the error and returns an empty array' do
        expect(Github::Helper).to receive(:query_with_logs).and_raise(StandardError.new("Test error"))
        expect(LoggerExtension).to receive(:log).with(
          :error,
          "Fetch prs error",
          { error_message: "Test error", repository: repo_full_name }
        )

        result = described_class.fetch_items(repo_full_name, item_type: :prs)

        expect(result).to eq([])
      end
    end
  end

  describe '.fetch_updates' do
    let(:repo_full_name) { 'owner/repo' }
    let(:last_synced_at) { '2025-01-01T00:00:00Z' }
    let(:search_query) { "repo:owner/repo updated:>=2025-01-01T00:00:00Z" }

    it 'fetches updates using the GraphQL search API' do
      mock_response = mock_github_query_with_variables(
        'search_query',
        { query: search_query, type: "ISSUE", cursor: nil },
        'search_query_mixed'
      )

      expect(Github::Helper).to receive(:query_with_logs).with(
        Queries::GlobalQueries.search_query,
        { query: search_query, type: "ISSUE", cursor: nil },
        repo_full_name,
        nil
      ).and_return(mock_response)

      expect(GithubRepositoryServices::ProcessingService).to receive(:process_search_response).with(
        mock_response.data.search.nodes,
        kind_of(Hash)
      )

      described_class.fetch_updates(repo_full_name, last_synced_at)
    end

    context 'when last_synced_at is nil' do
      it 'fetches all updates without date restriction' do
        mock_response = mock_github_query_with_variables(
          'search_query',
          { query: "repo:owner/repo", type: "ISSUE", cursor: nil },
          'search_query_mixed'
        )

        expect(Github::Helper).to receive(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: "repo:owner/repo", type: "ISSUE", cursor: nil },
          repo_full_name,
          nil
        ).and_return(mock_response)

        described_class.fetch_updates(repo_full_name, nil)
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

    it 'fetches user contributions using the GraphQL search API' do
      mock_response = mock_github_query_with_variables(
        'search_query',
        { query: search_query, type: "ISSUE", cursor: nil },
        'search_query_prs'
      )

      expect(Github::Helper).to receive(:query_with_logs).with(
        Queries::GlobalQueries.search_query,
        { query: search_query, type: "ISSUE", cursor: nil },
        nil,
        username
      ).and_return(mock_response)

      expect(GithubRepositoryServices::ProcessingService).to receive(:process_search_response).with(
        mock_response.data.search.nodes,
        items
      )

      described_class.fetch_user_contributions(username, items, contrib_type, last_polled_at_date)
    end

    context 'when last_polled_at_date is nil' do
      it 'fetches all contributions without date restriction' do
        mock_response = mock_github_query_with_variables(
          'search_query',
          { query: "author:test-user is:public is:pr", type: "ISSUE", cursor: nil },
          'search_query_prs'
        )

        expect(Github::Helper).to receive(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: "author:test-user is:public is:pr", type: "ISSUE", cursor: nil },
          nil,
          username
        ).and_return(mock_response)

        described_class.fetch_user_contributions(username, items, contrib_type, nil)
      end
    end

    context 'when contrib_type is :issues' do
      let(:contrib_type) { :issues }
      let(:search_query) { "author:test-user is:public is:issue updated:>=2025-01-01T00:00:00Z" }

      it 'uses the correct search query' do
        mock_response = mock_github_query_with_variables(
          'search_query',
          { query: search_query, type: "ISSUE", cursor: nil },
          'search_query_issues'
        )

        expect(Github::Helper).to receive(:query_with_logs).with(
          Queries::GlobalQueries.search_query,
          { query: search_query, type: "ISSUE", cursor: nil },
          nil,
          username
        ).and_return(mock_response)

        described_class.fetch_user_contributions(username, items, contrib_type, last_polled_at_date)
      end
    end
  end
end
