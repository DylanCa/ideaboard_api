require 'rails_helper'

RSpec.describe RepositoryTierUpdateWorker do
  describe '#execute' do
    let(:owner_token_repos) { [ create(:github_repository, full_name: 'owner/repo1') ] }
    let(:contributor_token_repos) { [ create(:github_repository, full_name: 'owner/repo2') ] }
    let(:global_pool_repos) { [ create(:github_repository, full_name: 'owner/repo3') ] }

    before do
      # Mock the tier-specific repository fetching methods
      allow(subject).to receive(:find_owner_token_repos).and_return(owner_token_repos)
      allow(subject).to receive(:find_contributor_token_repos).and_return(contributor_token_repos)
      allow(subject).to receive(:find_global_pool_repos).and_return(global_pool_repos)

      # Mock the repository update worker
      allow(RepositoryUpdateWorker).to receive(:perform_async)
    end

    context 'with owner_token tier' do
      it 'schedules updates for repositories with owner tokens' do
        result = subject.execute('owner_token')

        expect(subject).to have_received(:find_owner_token_repos)
        expect(RepositoryUpdateWorker).to have_received(:perform_async).with('owner/repo1')
        expect(result).to include(
                            tier: 'owner_token',
                            repos_updated_count: 1
                          )
      end
    end

    context 'with contributor_token tier' do
      it 'schedules updates for repositories with contributor tokens' do
        result = subject.execute('contributor_token')

        expect(subject).to have_received(:find_contributor_token_repos)
        expect(RepositoryUpdateWorker).to have_received(:perform_async).with('owner/repo2')
        expect(result).to include(
                            tier: 'contributor_token',
                            repos_updated_count: 1
                          )
      end
    end

    context 'with global_pool tier' do
      it 'schedules updates for repositories in the global pool' do
        result = subject.execute('global_pool')

        expect(subject).to have_received(:find_global_pool_repos)
        expect(RepositoryUpdateWorker).to have_received(:perform_async).with('owner/repo3')
        expect(result).to include(
                            tier: 'global_pool',
                            repos_updated_count: 1
                          )
      end
    end

    context 'with invalid tier' do
      it 'returns an empty array when tier is invalid' do
        result = subject.execute('invalid_tier')

        expect(result).to include(
                            tier: 'invalid_tier',
                            repos_updated_count: 0
                          )
        expect(RepositoryUpdateWorker).not_to have_received(:perform_async)
      end
    end

    context 'when no repositories are found for a tier' do
      before do
        allow(subject).to receive(:find_owner_token_repos).and_return([])
      end

      it 'returns zero repos updated' do
        result = subject.execute('owner_token')

        expect(result).to include(
                            tier: 'owner_token',
                            repos_updated_count: 0
                          )
        expect(RepositoryUpdateWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe 'private methods' do
    let!(:recent_repo) { create(:github_repository, last_polled_at: Time.current) }
    let!(:old_repo) { create(:github_repository, last_polled_at: 2.hours.ago) }
    let!(:never_polled_repo) { create(:github_repository, last_polled_at: nil) }

    describe '#find_owner_token_repos' do
      # These tests would need more setup with the associations
      # between github_accounts, user_tokens, and repositories
      it 'finds repositories that have an owner with tokens and need polling' do
        # Specific implementation would depend on how to mock the complex join
        # Consider testing the query directly instead of mocking it
        pending "Test requires complex setup of associations"
      end
    end

    describe '#find_contributor_token_repos' do
      it 'finds repositories with contributors that have tokens and need polling' do
        # Similarly would need significant setup with user_repository_stats
        pending "Test requires complex setup of associations"
      end
    end

    describe '#find_global_pool_repos' do
      it 'finds repositories that have not been polled recently' do
        allow(GithubRepository).to receive(:where).and_call_original

        # Call through the private method
        repos = subject.send(:find_global_pool_repos)

        # Verify this returns repositories that haven't been polled recently
        expect(repos).to include(old_repo)
        expect(repos).to include(never_polled_repo)
        expect(repos).not_to include(recent_repo)
      end
    end
  end
end
