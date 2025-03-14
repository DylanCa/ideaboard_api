require 'rails_helper'

RSpec.describe UserRepositoriesFetcherWorker do
  describe '#execute' do
    let!(:user) { create(:user, :with_github_account, :with_access_token) }

    it 'fetches and persists user repositories' do
      # Create a fresh mock for this test
      response = create_response_from_fixture(Rails.root.join("spec/fixtures/github_api/user_repositories.json"))

      allow(Github::Helper).to receive(:query_with_logs)
                                 .with(anything, nil, { token: user.access_token })
                                 .and_return(response)

      expect {
        result = subject.execute(user.id)

        expect(result).to include(
                            repos_count: 2,
                            username: user.github_account.github_username
                          )
      }.to change(GithubRepository, :count).by(2)
    end

    it 'returns nil when user does not exist' do
      result = subject.execute(999999)
      expect(result).to be_nil
    end

    it 'returns nil when user has no github account' do
      user_without_github = create(:user)
      result = subject.execute(user_without_github.id)
      expect(result).to be_nil
    end

    it 'returns nil when API response has no repositories' do
      response = create_response_from_fixture(Rails.root.join("spec/fixtures/github_api/user_repositories.json"))
      allow(response.data.viewer.repositories).to receive(:nodes).and_return(nil)

      allow(Github::Helper).to receive(:query_with_logs)
                                 .with(anything, nil, { token: user.access_token })
                                 .and_return(response)

      result = subject.execute(user.id)
      expect(result).to be_nil
    end

    it 'handles GraphQL API errors' do
      allow(Github::Helper).to receive(:query_with_logs)
                                 .and_raise(StandardError.new("API error"))

      expect { subject.execute(user.id) }.to raise_error(StandardError, "API error")
    end

    it 'handles persistence errors' do
      response = create_response_from_fixture(Rails.root.join("spec/fixtures/github_api/user_repositories.json"))

      allow(Github::Helper).to receive(:query_with_logs)
                                 .with(anything, nil, { token: user.access_token })
                                 .and_return(response)

      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many)
                                                            .and_raise(StandardError.new("Database error"))

      expect { subject.execute(user.id) }.to raise_error(StandardError, "Database error")
    end
  end
end
