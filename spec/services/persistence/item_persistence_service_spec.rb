require 'rails_helper'

RSpec.describe Persistence::ItemPersistenceService do
  describe '.persist_many' do
    let(:repo) { create(:github_repository) }

    context 'when persisting pull requests' do
      # Instead of extensively mocking PR objects, use fixture data
      let(:prs_response) { mock_github_query('repository_prs') }
      let(:items) { prs_response.data.repository.pull_requests.nodes }

      it 'persists pull requests and their labels' do
        expect {
          described_class.persist_many(items, repo, type: :prs)
        }.to change(PullRequest, :count).by(items.count)

        # Additional expectations to test label creation/association
        expect(Label.count).to be > 0
        expect(PullRequestLabel.count).to be > 0
      end
    end

    context 'when persisting issues' do
      # Use fixture data instead of mocks
      let(:issues_response) { mock_github_query('repository_issues') }
      let(:items) { issues_response.data.repository.issues.nodes }

      it 'persists issues and their labels' do
        expect {
          described_class.persist_many(items, repo, type: :issues)
        }.to change(Issue, :count).by(items.count)

        # Verify label associations
        expect(Label.count).to be > 0
        expect(IssueLabel.count).to be > 0
      end
    end

    context 'with invalid inputs' do
      it 'raises ArgumentError when items is nil' do
        expect {
          described_class.persist_many(nil, repo, type: :prs)
        }.to raise_error(ArgumentError, "Items cannot be nil")
      end

      it 'raises ArgumentError when repository is nil' do
        expect {
          described_class.persist_many([ double('PR') ], nil, type: :prs)
        }.to raise_error(ArgumentError, "GitHub Repository cannot be nil")
      end

      it 'raises ArgumentError when type is invalid' do
        expect {
          described_class.persist_many([ double('PR') ], repo, type: :invalid)
        }.to raise_error(ArgumentError, "Type should be either :prs or :issues")
      end
    end
  end
end
