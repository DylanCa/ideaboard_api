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
    let!(:old_repo) { create(:github_repository, last_polled_at: 13.hours.ago) }
    let!(:never_polled_repo) { create(:github_repository, last_polled_at: nil) }

    describe '#find_owner_token_repos' do
      it 'finds repositories that have an owner with tokens and need polling' do
        # Create a user with token and github account
        user = create(:user, :with_access_token)
        github_account = create(:github_account, user: user, github_username: 'test-owner')

        # Create repository owned by this user
        fresh_repo = create(:github_repository, author_username: 'test-owner', last_polled_at: 30.minutes.ago)
        stale_repo = create(:github_repository, author_username: 'test-owner', last_polled_at: 2.hours.ago)

        # Create repository with different owner
        other_repo = create(:github_repository, author_username: 'other-owner')

        repos = subject.send(:find_owner_token_repos)

        expect(repos).to include(stale_repo)
        expect(repos).not_to include(fresh_repo) # Too recently polled
        expect(repos).not_to include(other_repo) # Different owner
      end
    end

    describe '#find_contributor_token_repos' do
      it 'finds repositories with contributors that have tokens and need polling' do
        # Create user with token
        user = create(:user, :with_access_token, token_usage_level: :contributed)

        # Create repositories
        fresh_repo = create(:github_repository, last_polled_at: 4.hours.ago)
        stale_repo = create(:github_repository, last_polled_at: 7.hours.ago)

        # Create user repository stats to establish contributions
        create(:user_repository_stat, user: user, github_repository: fresh_repo)
        create(:user_repository_stat, user: user, github_repository: stale_repo)

        # Repository without contributions
        other_repo = create(:github_repository, last_polled_at: 7.hours.ago)

        repos = subject.send(:find_contributor_token_repos)

        expect(repos).to include(stale_repo)
        expect(repos).not_to include(fresh_repo) # Too recently polled
        expect(repos).not_to include(other_repo) # No contributions
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
