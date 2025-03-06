require 'rails_helper'

RSpec.describe RepositoryDataFetcherWorker do
  describe '#execute' do
    let(:repo_full_name) { 'owner/repo' }
    let(:repo_id) { 123 }

    before do
      allow(RepositoryFetcherWorker).to receive_message_chain(:new, :perform).and_return({ 'id' => repo_id })
      allow(ItemsFetcherWorker).to receive(:perform_async)
    end

    it 'fetches repository data and schedules item fetching' do
      result = subject.execute(repo_full_name)

      expect(RepositoryFetcherWorker).to have_received(:new)
      expect(ItemsFetcherWorker).to have_received(:perform_async).with(repo_id, 'prs')
      expect(ItemsFetcherWorker).to have_received(:perform_async).with(repo_id, 'issues')

      expect(result).to include(
                          repository: repo_full_name,
                          fetched: true
                        )
    end

    context 'when repository fetching fails' do
      before do
        allow(RepositoryFetcherWorker).to receive_message_chain(:new, :perform).and_return(nil)
      end

      it 'does not schedule item fetching' do
        result = subject.execute(repo_full_name)

        expect(result).to be_nil
        expect(ItemsFetcherWorker).not_to have_received(:perform_async)
      end
    end

    context 'when repository id is missing' do
      before do
        allow(RepositoryFetcherWorker).to receive_message_chain(:new, :perform).and_return({})
      end

      it 'does not schedule item fetching' do
        result = subject.execute(repo_full_name)

        expect(result).to be_nil
        expect(ItemsFetcherWorker).not_to have_received(:perform_async)
      end
    end
  end
end
