require 'rails_helper'

RSpec.describe RepositoryTierUpdateWorker do
  describe '#execute' do
    let!(:user_with_token) { create(:user, :with_github_account, :with_access_token) }
    let!(:contributor_user) { create(:user, :with_access_token, token_usage_level: :contributed) }

    let!(:owner_repo) { create(:github_repository, author_username: user_with_token.github_username, last_polled_at: 2.hours.ago) }
    let!(:contrib_repo) { create(:github_repository, last_polled_at: 7.hours.ago) }
    let!(:global_repo) { create(:github_repository, last_polled_at: 13.hours.ago) }
    let!(:fresh_repo) { create(:github_repository, last_polled_at: 30.minutes.ago) }

    before do
      create(:user_repository_stat, user: contributor_user, github_repository: contrib_repo)

      allow(RepositoryUpdateWorker).to receive(:perform_async)
    end

    it 'processes owner_token tier correctly' do
      result = subject.execute('owner_token')

      expect(result).to include(tier: 'owner_token')
      expect(result[:repos_updated_count]).to eq(1)
      expect(RepositoryUpdateWorker).to have_received(:perform_async).with(owner_repo.full_name)
      expect(RepositoryUpdateWorker).not_to have_received(:perform_async).with(fresh_repo.full_name)
    end

    it 'processes contributor_token tier correctly' do
      result = subject.execute('contributor_token')

      expect(result).to include(tier: 'contributor_token')
      expect(result[:repos_updated_count]).to eq(1)
      expect(RepositoryUpdateWorker).to have_received(:perform_async).with(contrib_repo.full_name)
    end

    it 'processes global_pool tier correctly' do
      result = subject.execute('global_pool')

      expect(result).to include(tier: 'global_pool')
      expect(result[:repos_updated_count]).to be >= 1
      expect(RepositoryUpdateWorker).to have_received(:perform_async).with(global_repo.full_name)
    end

    it 'returns zero repos count for invalid tier' do
      result = subject.execute('invalid_tier')

      expect(result).to include(tier: 'invalid_tier', repos_updated_count: 0)
      expect(RepositoryUpdateWorker).not_to have_received(:perform_async)
    end

    it 'handles database errors gracefully' do
      allow(GithubRepository).to receive(:joins).and_raise(ActiveRecord::StatementInvalid.new("Database error"))

      expect { subject.execute('owner_token') }.to raise_error(ActiveRecord::StatementInvalid, "Database error")
      expect(RepositoryUpdateWorker).not_to have_received(:perform_async)
    end
  end
end
