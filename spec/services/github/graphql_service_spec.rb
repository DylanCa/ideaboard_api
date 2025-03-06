require 'rails_helper'

RSpec.describe Github::GraphqlService do
  describe '.fetch_current_user_data' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }

    it 'fetches user data from GitHub' do
      mock_github_query(:user_data)

      result = described_class.fetch_current_user_data(user)

      expect(result.login).to eq('testuser')
      expect(result.email).to eq('test@example.com')
      expect(result.database_id).to eq(12345)
    end
  end

  describe '.fetch_current_user_repositories' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }

    it 'schedules a job to fetch user repositories' do
      allow(UserRepositoriesFetcherWorker).to receive(:perform_async)

      described_class.fetch_current_user_repositories(user)

      expect(UserRepositoriesFetcherWorker).to have_received(:perform_async).with(user.id)
    end
  end

  describe '.update_repositories_data' do
    let!(:repo1) { create(:github_repository, full_name: 'owner/repo1') }
    let!(:repo2) { create(:github_repository, full_name: 'owner/repo2') }

    it 'schedules repository data updates for all repositories' do
      allow(RepositoryDataFetcherWorker).to receive(:perform_async)

      described_class.update_repositories_data

      expect(RepositoryDataFetcherWorker).to have_received(:perform_async).with('owner/repo1')
      expect(RepositoryDataFetcherWorker).to have_received(:perform_async).with('owner/repo2')
    end
  end

  describe '.add_repo_by_name' do
    it 'schedules a repository data update for the specified repository' do
      allow(RepositoryDataFetcherWorker).to receive(:perform_async)

      described_class.add_repo_by_name('owner/repo')

      expect(RepositoryDataFetcherWorker).to have_received(:perform_async).with('owner/repo')
    end
  end

  describe '.fetch_repository_update' do
    it 'schedules a repository update for the specified repository' do
      allow(RepositoryUpdateWorker).to receive(:perform_async)

      described_class.fetch_repository_update('owner/repo')

      expect(RepositoryUpdateWorker).to have_received(:perform_async).with('owner/repo')
    end
  end

  describe '.fetch_user_contributions' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }

    it 'schedules a job to fetch user contributions' do
      allow(UserContributionsFetcherWorker).to receive(:perform_async)

      described_class.fetch_user_contributions(user)

      expect(UserContributionsFetcherWorker).to have_received(:perform_async).with(user.id)
    end
  end
end
