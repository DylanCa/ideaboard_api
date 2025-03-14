require 'rails_helper'

RSpec.describe UserContributionsFetcherWorker do
  describe '#execute' do
    let!(:user) { create(:user, :with_github_account, :with_access_token) }
    let(:github_username) { user.github_account.github_username }

    before do
      # Mock only the Github API calls
      mock_repos_response = mock_github_query('user_repositories')
      mock_prs_response = mock_github_query('search_query_prs')
      mock_issues_response = mock_github_query('search_query_issues')

      # Allow query service to use our mocked responses
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos)
                                                         .with(github_username, anything)
                                                         .and_return([ mock_repos_response.data.viewer.repositories.nodes ])

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_contributions)
                                                         .with(github_username, anything, :prs, anything)
                                                         .and_return(mock_prs_response)

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_contributions)
                                                         .with(github_username, anything, :issues, anything)
                                                         .and_return(mock_issues_response)

      allow(UserRepositoryStatWorker).to receive(:perform_async)
    end

    it 'fetches and persists user repositories and contributions' do
      old_polled_at = user.github_account.last_polled_at

      expect {
        result = subject.execute(user.id)

        expect(result).to include(
                            username: github_username,
                            repos_count: kind_of(Integer),
                            prs_count: kind_of(Integer),
                            issues_count: kind_of(Integer)
                          )

        user.github_account.reload
        expect(user.github_account.last_polled_at).to be > old_polled_at if old_polled_at
      }.to change { GithubRepository.count }

      expect(UserRepositoryStatWorker).to have_received(:perform_async).with(user.id)
    end

    it 'returns nil when user does not exist' do
      result = subject.execute(999999)
      expect(result).to be_nil
      expect(UserRepositoryStatWorker).not_to have_received(:perform_async)
    end

    it 'returns nil when user has no github account' do
      user_without_github = create(:user)
      result = subject.execute(user_without_github.id)
      expect(result).to be_nil
      expect(UserRepositoryStatWorker).not_to have_received(:perform_async)
    end

    it 'still processes contributions when no new repositories are found' do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos)
                                                         .with(github_username, anything)
                                                         .and_return(nil)

      result = subject.execute(user.id)

      expect(result).not_to be_nil
      expect(result[:username]).to eq(github_username)
      expect(UserRepositoryStatWorker).to have_received(:perform_async).with(user.id)
    end

    it 'handles errors during repository fetching' do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_user_repos)
                                                         .and_raise(StandardError.new("API error"))

      expect { subject.execute(user.id) }.to raise_error(StandardError, "API error")
    end
  end
end
