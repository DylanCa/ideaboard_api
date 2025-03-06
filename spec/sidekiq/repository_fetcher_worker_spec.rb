require 'rails_helper'

RSpec.describe RepositoryFetcherWorker do
  describe '#execute' do
    let(:repo_name) { 'owner/repo' }
    let(:mock_repository) { double('Repository') }
    let(:persisted_repo) { { 'id' => 123 } }

    before do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_repository).with(repo_name).and_return(mock_repository)
      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many).with([ mock_repository ]).and_return([ persisted_repo ])
    end

    it 'fetches repository data and persists it' do
      result = subject.execute(repo_name)

      expect(GithubRepositoryServices::QueryService).to have_received(:fetch_repository).with(repo_name)
      expect(Persistence::RepositoryPersistenceService).to have_received(:persist_many).with([ mock_repository ])
      expect(result).to eq(persisted_repo)
    end

    context 'when repository fetching fails' do
      before do
        allow(GithubRepositoryServices::QueryService).to receive(:fetch_repository).with(repo_name).and_return(nil)
      end

      it 'returns nil without persisting' do
        result = subject.execute(repo_name)

        expect(result).to be_nil
        expect(Persistence::RepositoryPersistenceService).not_to have_received(:persist_many)
      end
    end

    context 'when persistence returns empty array' do
      before do
        allow(Persistence::RepositoryPersistenceService).to receive(:persist_many).with([ mock_repository ]).and_return([])
      end

      it 'returns nil' do
        result = subject.execute(repo_name)

        expect(result).to be_nil
      end
    end
  end
end
