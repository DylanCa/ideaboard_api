require 'rails_helper'

RSpec.describe UserRepositoriesFetcherWorker do
  describe '#execute' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }
    let(:user_id) { user.id }
    let(:github_username) { user.github_account.github_username }
    let(:mock_response) { mock_github_query('user_repositories') }

    before do
      allow(User).to receive(:find).with(user_id).and_return(user)

      mock_response = mock_github_query('user_repositories')

      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos).and_return([ [ mock_response.data.viewer.repositories.nodes ] ])
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_contributions)

      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many)
      allow(GithubRepositoryServices::ProcessingService).to receive(:process_contributions)
    end

    it 'fetches and persists user repositories' do
      result = subject.execute(user_id)

      expect(User).to have_received(:find).with(user_id)
      expect(Github::Helper).to have_received(:query_with_logs).with(
        Queries::UserQueries.user_repositories,
        nil,
        { token: user.access_token }
      )
      expect(Persistence::RepositoryPersistenceService).to have_received(:persist_many).with(mock_response.data.viewer.repositories.nodes)

      expect(result).to include(
                          repos_count: 2,
                          username: github_username
                        )
    end

    context 'when user does not exist' do
      before do
        allow(User).to receive(:find).with(user_id).and_return(nil)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
        expect(Github::Helper).not_to have_received(:query_with_logs)
        expect(Persistence::RepositoryPersistenceService).not_to have_received(:persist_many)
      end
    end

    context 'when user has no github account' do
      before do
        user.github_account = nil
        allow(User).to receive(:find).with(user_id).and_return(user)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
        expect(Github::Helper).not_to have_received(:query_with_logs)
        expect(Persistence::RepositoryPersistenceService).not_to have_received(:persist_many)
      end
    end

    context 'when API response has no repositories' do
      before do
        mock_response = mock_github_query('user_repositories')
        allow(mock_response.data.viewer.repositories).to receive(:nodes).and_return(nil)
        allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
      end

      it 'returns early without persisting' do
        result = subject.execute(user_id)

        expect(result).to be_nil
        expect(Github::Helper).to have_received(:query_with_logs)
        expect(Persistence::RepositoryPersistenceService).not_to have_received(:persist_many)
      end
    end
  end
end
