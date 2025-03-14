require 'rails_helper'

RSpec.describe RepositoryUpdateWorker do
  describe '#execute' do
    let!(:repository) { create(:github_repository, full_name: 'owner/repo', last_polled_at: 2.days.ago) }

    before do
      mock_github_query('repository_data')
      mock_github_query('repository_prs')
      mock_github_query('repository_issues')

      allow(RepositoryFetcherWorker).to receive(:new).and_return(
        instance_double(RepositoryFetcherWorker, perform: { 'id' => repository.id })
      )
    end

    it 'updates repository data and processes changes' do
      old_last_polled_at = repository.last_polled_at

      create_list(:pull_request, 2, github_repository: repository)
      create_list(:issue, 2, github_repository: repository)

      # Execute the worker
      result = subject.execute(repository.full_name)
      repository.reload

      expect(repository.last_polled_at).to be > old_last_polled_at

      expect(result).to include(
                          full_name: repository.full_name,
                          updated: true
                        )

      expect(result).to include(:prs_count, :issues_count)
    end

    it 'handles non-existent repositories' do
      result = subject.execute('nonexistent/repo')
      expect(result).to be_nil
    end

    it 'updates last_polled_at even when no changes are found' do
      old_last_polled_at = repository.last_polled_at

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_updates).and_return({
                                                                                            repositories: {},
                                                                                            prs: [],
                                                                                            issues: []
                                                                                          })

      result = subject.execute(repository.full_name)
      repository.reload

      expect(repository.last_polled_at).to be > old_last_polled_at
      expect(result).to include(
                          full_name: repository.full_name,
                          updated: true,
                          prs_count: 0,
                          issues_count: 0
                        )
    end

    it 'continues processing when repository fetching fails' do
      allow(RepositoryFetcherWorker).to receive(:new).and_return(
        instance_double(RepositoryFetcherWorker, perform: nil)
      )

      old_last_polled_at = repository.last_polled_at
      result = subject.execute(repository.full_name)
      repository.reload

      expect(repository.last_polled_at).to be > old_last_polled_at
      expect(result).to include(full_name: repository.full_name, updated: true)
    end

    it 'handles errors during update processing' do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_updates)
                                                         .and_raise(StandardError.new("Test error"))

      expect {
        subject.execute(repository.full_name)
      }.to raise_error(StandardError, "Test error")

      repository.reload
      expect(repository.last_polled_at).to be <= 2.days.ago
    end
  end
end
