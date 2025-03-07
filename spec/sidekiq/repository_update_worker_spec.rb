require 'rails_helper'

RSpec.describe RepositoryUpdateWorker do
  describe '#execute' do
    let(:repo_name) { 'owner/repo' }
    let(:repo) { create(:github_repository, full_name: repo_name, last_polled_at: 2.days.ago) }

    before do
      allow(GithubRepository).to receive(:find_by_full_name).with(repo_name).and_return(repo)
      allow(RepositoryFetcherWorker).to receive_message_chain(:new, :perform).and_return({ "id" => repo.id })
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_updates).and_return({
                                                                                            repositories: { repo_name => repo },
                                                                                            prs: [ double('PR1'), double('PR2') ],
                                                                                            issues: [ double('Issue1'), double('Issue2') ]
                                                                                          })
      allow(GithubRepositoryServices::ProcessingService).to receive(:process_contributions)
      allow(repo).to receive(:update)
    end

    it 'updates repository data and processes changes' do
      result = subject.execute(repo_name)

      expect(GithubRepository).to have_received(:find_by_full_name).with(repo_name)
      expect(RepositoryFetcherWorker).to have_received(:new)
      expect(GithubRepositoryServices::QueryService).to have_received(:fetch_updates).with(repo_name, repo.last_polled_at_date)
      expect(GithubRepositoryServices::ProcessingService).to have_received(:process_contributions)
      expect(repo).to have_received(:update).with(hash_including(:last_polled_at))

      expect(result).to include(
                          full_name: repo_name,
                          updated: true,
                          prs_count: 2,
                          issues_count: 2
                        )
    end

    context 'when repository is not found' do
      before do
        allow(GithubRepository).to receive(:find_by_full_name).with(repo_name).and_return(nil)
      end

      it 'returns nil without processing' do
        result = subject.execute(repo_name)

        expect(result).to be_nil
        expect(RepositoryFetcherWorker).not_to have_received(:new)
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_updates)
        expect(GithubRepositoryServices::ProcessingService).not_to have_received(:process_contributions)
      end
    end

    context 'when no changes are found' do
      before do
        allow(GithubRepositoryServices::QueryService).to receive(:fetch_updates).and_return({
                                                                                              repositories: {},
                                                                                              prs: [],
                                                                                              issues: []
                                                                                            })
      end

      it 'still updates the last_polled_at timestamp' do
        result = subject.execute(repo_name)

        expect(repo).to have_received(:update).with(hash_including(:last_polled_at))
        expect(result).to include(
                            full_name: repo_name,
                            updated: true,
                            prs_count: 0,
                            issues_count: 0
                          )
      end
    end

    context 'when repository fetching fails' do
      before do
        allow(RepositoryFetcherWorker).to receive_message_chain(:new, :perform).and_return(nil)
      end

      it 'still proceeds with updates' do
        result = subject.execute(repo_name)

        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_updates)
        expect(repo).to have_received(:update).with(hash_including(:last_polled_at))
      end
    end
  end
end
