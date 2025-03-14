require 'rails_helper'

RSpec.describe RepositoryFetcherWorker do
  describe '#execute' do
    let(:repo_name) { 'owner/repo' }

    before do
      mock_response = mock_github_query('repository_data')

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_repository)
                                                         .with(repo_name)
                                                         .and_return(mock_response.data.repository)
    end

    it 'fetches repository data and persists it to the database' do
      expect {
        subject.execute(repo_name)
      }.to change(GithubRepository, :count).by(1)

      created_repo = GithubRepository.find_by(full_name: repo_name)
      expect(created_repo).not_to be_nil
    end

    it 'updates existing repository when it already exists' do
      existing_repo = create(:github_repository,
                             full_name: repo_name,
                             github_id: 'R_kgDOG2TNuA',
                             stars_count: 100)

      expect {
        result = subject.execute(repo_name)
        expect(result['id']).to eq(existing_repo.id)
      }.not_to change(GithubRepository, :count)

      existing_repo.reload
      expect(existing_repo.stars_count).to eq(750)
    end

    it 'handles repository topics correctly' do
      expect {
        subject.execute(repo_name)
      }.to change(Topic, :count).by(3)

      created_repo = GithubRepository.find_by(full_name: repo_name)
      expect(created_repo.topics.count).to eq(3)
      expect(created_repo.topics.pluck(:name)).to include('ruby', 'rails', 'api')
    end

    it 'returns nil when repository fetching fails' do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_repository)
                                                         .with(repo_name)
                                                         .and_return(nil)

      expect {
        result = subject.execute(repo_name)
        expect(result).to be_nil
      }.not_to change(GithubRepository, :count)
    end

    it 'handles errors during repository persistence' do
      allow(Persistence::RepositoryPersistenceService).to receive(:persist_many)
                                                            .and_raise(StandardError.new("Persistence error"))

      expect {
        expect { subject.execute(repo_name) }.to raise_error(StandardError, "Persistence error")
      }.not_to change(GithubRepository, :count)
    end
  end
end
