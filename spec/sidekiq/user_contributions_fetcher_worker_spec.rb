require 'rails_helper'

RSpec.describe UserContributionsFetcherWorker do
  describe '#execute' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }
    let(:user_id) { user.id }
    let(:github_username) { user.github_account.github_username }

    before do
      allow(User).to receive(:find_by).with(id: user_id).and_return(user)
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos).and_return([ [ double('Repository') ] ])
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_contributions)
      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many)
      allow(GithubRepositoryServices::ProcessingService).to receive(:process_contributions)
      allow(user.github_account).to receive(:update)
      allow(UserRepositoryStatWorker).to receive(:perform_async)
    end

    it 'fetches newly created repos and contributions' do
      result = subject.execute(user_id)

      expect(User).to have_received(:find_by).with(id: user_id)
      expect(GithubRepositoryServices::QueryService).to have_received(:fetch_user_repos).with(
        github_username,
        user.github_account.last_polled_at_date
      )
      expect(Persistence::RepositoryPersistenceService).to have_received(:persist_many)

      expect(GithubRepositoryServices::QueryService).to have_received(:fetch_user_contributions).twice
      expect(GithubRepositoryServices::ProcessingService).to have_received(:process_contributions)

      expect(user.github_account).to have_received(:update).with(hash_including(:last_polled_at))
      expect(UserRepositoryStatWorker).to have_received(:perform_async).with(user_id)

      expect(result).to include(
                          username: github_username,
                          repos_count: 0,
                          prs_count: 0,
                          issues_count: 0
                        )
    end

    context 'when user does not exist' do
      before do
        allow(User).to receive(:find_by).with(id: user_id).and_return(nil)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_user_repos)
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_user_contributions)
        expect(UserRepositoryStatWorker).not_to have_received(:perform_async)
      end
    end

    context 'when user has no github account' do
      before do
        user.github_account = nil
        allow(User).to receive(:find_by).with(id: user_id).and_return(user)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_user_repos)
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_user_contributions)
        expect(UserRepositoryStatWorker).not_to have_received(:perform_async)
      end
    end

    context 'when new repositories are fetched' do
      it 'persists them correctly' do
        allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos).and_return([ [ double('Repository') ] ])

        subject.execute(user_id)

        expect(Persistence::RepositoryPersistenceService).to have_received(:persist_many)
      end
    end

    context 'when no new repositories are fetched' do
      it 'still processes contributions' do
        allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos).and_return(nil)

        subject.execute(user_id)

        expect(Persistence::RepositoryPersistenceService).not_to have_received(:persist_many)
        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_user_contributions).twice
      end
    end
  end
end
