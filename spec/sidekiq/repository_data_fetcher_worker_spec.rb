require 'rails_helper'

RSpec.describe RepositoryDataFetcherWorker do
  describe '#execute' do
    let(:repo_full_name) { 'owner/repo' }
    let!(:repository) { create(:github_repository, full_name: repo_full_name) }

    before do
      mock_github_query('repository_data')
      allow(ItemsFetcherWorker).to receive(:perform_async)
    end

    it 'fetches repository data and schedules item fetching' do
      fetcher_worker = instance_double(RepositoryFetcherWorker)
      allow(fetcher_worker).to receive(:perform).with(repo_full_name).and_return({ 'id' => repository.id })
      allow(RepositoryFetcherWorker).to receive(:new).and_return(fetcher_worker)

      result = subject.execute(repo_full_name)

      expect(ItemsFetcherWorker).to have_received(:perform_async).with(repository.id, 'prs')
      expect(ItemsFetcherWorker).to have_received(:perform_async).with(repository.id, 'issues')

      expect(result).to include(
                          repository: repo_full_name,
                          fetched: true
                        )
    end

    it 'returns nil when repository fetching fails' do
      fetcher_worker = instance_double(RepositoryFetcherWorker)
      allow(fetcher_worker).to receive(:perform).with(repo_full_name).and_return(nil)
      allow(RepositoryFetcherWorker).to receive(:new).and_return(fetcher_worker)

      result = subject.execute(repo_full_name)
      expect(result).to be_nil
      expect(ItemsFetcherWorker).not_to have_received(:perform_async)
    end

    it 'returns nil when repository id is missing from fetcher response' do
      fetcher_worker = instance_double(RepositoryFetcherWorker)
      allow(fetcher_worker).to receive(:perform).with(repo_full_name).and_return({})
      allow(RepositoryFetcherWorker).to receive(:new).and_return(fetcher_worker)

      result = subject.execute(repo_full_name)
      expect(result).to be_nil
      expect(ItemsFetcherWorker).not_to have_received(:perform_async)
    end

    it 'handles errors from fetcher worker' do
      fetcher_worker = instance_double(RepositoryFetcherWorker)
      allow(fetcher_worker).to receive(:perform).with(repo_full_name).and_raise(StandardError.new("Fetcher error"))
      allow(RepositoryFetcherWorker).to receive(:new).and_return(fetcher_worker)

      expect { subject.execute(repo_full_name) }.to raise_error(StandardError, "Fetcher error")
      expect(ItemsFetcherWorker).not_to have_received(:perform_async)
    end
  end
end
