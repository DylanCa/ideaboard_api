require 'rails_helper'

RSpec.describe UserRepositoriesFetcherWorker do
  describe '#execute' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }
    let(:user_id) { user.id }
    let(:github_username) { user.github_account.github_username }
    let(:mock_repo_nodes) { [ double('Repository1'), double('Repository2') ] }
    let(:mock_response) do
      OpenStruct.new(
        data: OpenStruct.new(
          viewer: OpenStruct.new(
            repositories: OpenStruct.new(
              nodes: mock_repo_nodes
            )
          )
        )
      )
    end

    before do
      allow(User).to receive(:find).with(user_id).and_return(user)
      allow(Github::Helper).to receive(:query_with_logs).and_return(mock_response)
      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many)
    end

    it 'fetches and persists user repositories' do
      result = subject.execute(user_id)

      expect(User).to have_received(:find).with(user_id)
      expect(Github::Helper).to have_received(:query_with_logs).with(
        Queries::UserQueries.user_repositories,
        nil,
        { token: user.access_token }
      )
      expect(Persistence::RepositoryPersistenceService).to have_received(:persist_many).with(mock_repo_nodes)

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
        allow(mock_response.data.viewer.repositories).to receive(:nodes).and_return(nil)
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
