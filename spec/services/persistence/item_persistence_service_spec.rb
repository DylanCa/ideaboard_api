require 'rails_helper'

RSpec.describe Persistence::ItemPersistenceService do
  describe '.persist_many' do
    let(:repo) { create(:github_repository) }

    context 'when persisting pull requests' do
      let(:pr) do
        double('PR',
               id: 'pr-123',
               labels: double('Labels', nodes: [ double('Label') ]),
               title: 'Test PR',
               url: 'https://github.com/test/pr',
               number: 1,
               author: double('Author', login: 'testuser'),
               merged_at: nil,
               closed_at: nil,
               created_at: '2025-01-01T00:00:00Z',
               updated_at: '2025-01-01T00:00:00Z',
               is_draft: false,
               total_comments_count: 0,
               commits: double('Commits', total_count: 1)
        )
      end
      let(:items) { [ pr ] }

      before do
        allow(Github::PullRequest).to receive(:from_github).and_return(
          OpenStruct.new(stringify_keys: { title: 'Test PR' })
        )
        allow(Github::Label).to receive(:from_github).and_return(
          OpenStruct.new(stringify_keys: { name: 'test-label' })
        )
        allow(repo.pull_requests).to receive(:upsert_all).and_return([ { 'id' => 1, 'github_id' => 'pr-123' } ])
        allow(Persistence::Helper).to receive(:insert_items_labels_if_any)
      end

      it 'persists pull requests and their labels' do
        described_class.persist_many(items, repo, type: :prs)

        expect(Github::PullRequest).to have_received(:from_github).with(pr, repo.id)
        expect(Github::Label).to have_received(:from_github)
        expect(repo.pull_requests).to have_received(:upsert_all)
        expect(Persistence::Helper).to have_received(:insert_items_labels_if_any).with(
          { 'pr-123' => [ { name: 'test-label' } ] },
          [ { 'id' => 1, 'github_id' => 'pr-123' } ],
          :prs
        )
      end
    end

    context 'when persisting issues' do
      let(:issue) do
        double('Issue',
               id: 'issue-123',
               labels: double('Labels', nodes: [ double('Label') ]),
               title: 'Test Issue',
               url: 'https://github.com/test/issue',
               number: 1,
               author: double('Author', login: 'testuser'),
               closed_at: nil,
               created_at: '2025-01-01T00:00:00Z',
               updated_at: '2025-01-01T00:00:00Z',
               comments: double('Comments', total_count: 0)
        )
      end
      let(:items) { [ issue ] }

      before do
        allow(Github::Issue).to receive(:from_github).and_return(
          OpenStruct.new(stringify_keys: { title: 'Test Issue' })
        )
        allow(Github::Label).to receive(:from_github).and_return(
          OpenStruct.new(stringify_keys: { name: 'test-label' })
        )
        allow(repo.issues).to receive(:upsert_all).and_return([ { 'id' => 1, 'github_id' => 'issue-123' } ])
        allow(Persistence::Helper).to receive(:insert_items_labels_if_any)
      end

      it 'persists issues and their labels' do
        described_class.persist_many(items, repo, type: :issues)

        expect(Github::Issue).to have_received(:from_github).with(issue, repo.id)
        expect(Github::Label).to have_received(:from_github)
        expect(repo.issues).to have_received(:upsert_all)
        expect(Persistence::Helper).to have_received(:insert_items_labels_if_any).with(
          { 'issue-123' => [ { name: 'test-label' } ] },
          [ { 'id' => 1, 'github_id' => 'issue-123' } ],
          :issues
        )
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
