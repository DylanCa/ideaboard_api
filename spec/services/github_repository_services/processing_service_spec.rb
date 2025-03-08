require 'rails_helper'

RSpec.describe GithubRepositoryServices::ProcessingService do
  describe '.process_contributions' do
    let(:mock_repo) { create(:github_repository) }
    let(:repositories) { { mock_repo.full_name => mock_repo } }

    # Use actual fixture data instead of doubles
    let(:search_response) { mock_github_query('search_query_mixed') }
    let(:items) do
      {
        repositories: repositories,
        prs: search_response.data.search.nodes.select { |n| n.__typename == "PullRequest" },
        issues: search_response.data.search.nodes.select { |n| n.__typename == "Issue" }
      }
    end

    before do
      allow(described_class).to receive(:ensure_repositories_exist).and_return(repositories)
      allow(GithubRepositoryServices::PersistenceService).to receive(:update_repositories_content)
    end

    it 'processes contributions by ensuring repositories exist and updating content' do
      described_class.process_contributions(items)

      expect(described_class).to have_received(:ensure_repositories_exist).with(repositories)
      expect(GithubRepositoryServices::PersistenceService).to have_received(:update_repositories_content).with(repositories, items)
    end
  end

  describe '.process_search_response' do
    # Use actual fixture data from GraphQLMocks
    let(:search_response) { mock_github_query('search_query_mixed') }
    let(:nodes) { search_response.data.search.nodes }
    let(:items) { { repositories: Set.new, prs: [], issues: [] } }

    it 'processes search results by categorizing nodes' do
      described_class.process_search_response(nodes, items)

      expect(items[:repositories].count).to eq(2)
      expect(items[:prs].count).to eq(1)
      expect(items[:issues].count).to eq(1)
    end
  end

  describe '.filter_items_by_repo' do
    let(:repo_name) { 'owner/repo' }
    # Use fixture data for more realistic testing
    let(:search_response) { mock_github_query('search_query_prs') }
    let(:items) { search_response.data.search.nodes }

    it 'filters items to only those matching the repository name' do
      result = described_class.filter_items_by_repo(items, repo_name)
      expect(result.all? { |item| item.repository.name_with_owner == repo_name }).to be true
    end

    context 'when no items match' do
      let(:repo_name) { 'nonexistent/repo' }

      it 'returns an empty array' do
        result = described_class.filter_items_by_repo(items, repo_name)
        expect(result).to be_empty
      end
    end
  end
end
