require 'rails_helper'

RSpec.describe GithubRepositoryServices::ProcessingService do
  describe '.process_contributions' do
    let(:mock_repo) { create(:github_repository) }
    let(:repositories) { { mock_repo.full_name => mock_repo } }
    let(:items) { { repositories: repositories, prs: [ double('PR') ], issues: [ double('Issue') ] } }

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
    let(:repository) { double('Repository', name_with_owner: 'owner/repo') }
    let(:pr_node) {
      double('PullRequestNode',
             __typename: 'PullRequest',
             repository: repository
      )
    }
    let(:issue_node) {
      double('IssueNode',
             __typename: 'Issue',
             repository: repository
      )
    }
    let(:repo_node) {
      double('RepositoryNode',
             __typename: 'Repository'
      )
    }
    let(:nodes) { [ pr_node, issue_node, repo_node ] }
    let(:items) { { repositories: Set.new, prs: [], issues: [] } }

    it 'processes search results by categorizing nodes' do
      described_class.process_search_response(nodes, items)

      expect(items[:repositories].count).to eq(1)
      expect(items[:prs].count).to eq(1)
      expect(items[:issues].count).to eq(1)
    end

    context 'when nodes have different types' do
      let(:unknown_node) { double('UnknownNode', __typename: 'Unknown') }
      let(:nodes) { [ pr_node, issue_node, repo_node, unknown_node ] }

      it 'only processes recognized node types' do
        described_class.process_search_response(nodes, items)

        expect(items[:repositories].count).to eq(1)
        expect(items[:prs].count).to eq(1)
        expect(items[:issues].count).to eq(1)
      end
    end
  end

  describe '.filter_items_by_repo' do
    let(:repo_name) { 'owner/repo' }
    let(:matching_repo) { double('Repository', name_with_owner: repo_name) }
    let(:non_matching_repo) { double('Repository', name_with_owner: 'other/repo') }
    let(:matching_item) { double('Item', repository: matching_repo) }
    let(:non_matching_item) { double('Item', repository: non_matching_repo) }
    let(:items) { [ matching_item, non_matching_item ] }

    it 'filters items to only those matching the repository name' do
      result = described_class.filter_items_by_repo(items, repo_name)

      expect(result).to eq([ matching_item ])
    end

    context 'when no items match' do
      let(:items) { [ non_matching_item ] }

      it 'returns an empty array' do
        result = described_class.filter_items_by_repo(items, repo_name)

        expect(result).to be_empty
      end
    end
  end
end
