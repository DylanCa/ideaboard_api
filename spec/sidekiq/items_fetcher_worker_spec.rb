require 'rails_helper'

RSpec.describe ItemsFetcherWorker do
  describe '#execute' do
    let!(:repository) { create(:github_repository, full_name: 'owner/repo') }

    before do
      mock_prs_response = mock_github_query('repository_prs')
      mock_issues_response = mock_github_query('repository_issues')

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_items)
                                                         .with(repository.full_name, item_type: :prs)
                                                         .and_return(mock_prs_response.data.repository.pull_requests.nodes)

      allow(GithubRepositoryServices::QueryService).to receive(:fetch_items)
                                                         .with(repository.full_name, item_type: :issues)
                                                         .and_return(mock_issues_response.data.repository.issues.nodes)
    end

    it 'fetches and persists both PRs and issues when type is both' do
      expect {
        result = subject.execute(repository.id, 'both')

        expect(result).to include(
                            repository_id: repository.id,
                            full_name: repository.full_name,
                            item_type: 'both',
                            prs_count: 2,
                            issues_count: 2
                          )
      }.to change { repository.pull_requests.count + repository.issues.count }.by(4)
    end

    it 'fetches and persists only PRs when type is prs' do
      expect {
        result = subject.execute(repository.id, 'prs')

        expect(result).to include(
                            repository_id: repository.id,
                            full_name: repository.full_name,
                            item_type: 'prs',
                            prs_count: 2,
                            issues_count: 0
                          )
      }.to change { repository.pull_requests.count }.by(2)
                                                    .and change { repository.issues.count }.by(0)
    end

    it 'fetches and persists only issues when type is issues' do
      expect {
        result = subject.execute(repository.id, 'issues')

        expect(result).to include(
                            repository_id: repository.id,
                            full_name: repository.full_name,
                            item_type: 'issues',
                            prs_count: 0,
                            issues_count: 2
                          )
      }.to change { repository.issues.count }.by(2)
                                             .and change { repository.pull_requests.count }.by(0)
    end

    it 'returns nil when repository is not found' do
      result = subject.execute(999999, 'both')
      expect(result).to be_nil
    end

    it 'handles errors in GitHub API calls' do
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_items)
                                                         .with(repository.full_name, item_type: :prs)
                                                         .and_raise(StandardError.new("API error"))

      expect { subject.execute(repository.id, 'prs') }.to raise_error(StandardError, "API error")
    end
  end
end
