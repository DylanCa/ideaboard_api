require 'rails_helper'

RSpec.describe Persistence::RepositoryPersistenceService do
  describe '.persist_many' do
    let(:repository) do
      double('Repository',
             id: 'repo-123',
             name_with_owner: 'owner/repo',
             repository_topics: double('Topics', nodes: [ double('Topic', topic: double('TopicName', name: 'test-topic')) ]),
             owner: double('Owner', login: 'owner'),
             name: 'repo',
             description: 'Repository description',
             primary_language: double('Language', name: 'Ruby'),
             is_fork: false,
             stargazer_count: 10,
             fork_count: 5,
             is_archived: false,
             is_disabled: false,
             license_info: double('License', key: 'mit'),
             created_at: '2025-01-01T00:00:00Z',
             updated_at: '2025-01-02T00:00:00Z'
      )
    end
    let(:repositories) { [ repository ] }

    before do
      allow(Github::Repository).to receive(:from_github).and_return(
        OpenStruct.new(stringify_keys: { full_name: 'owner/repo' })
      )
      allow(Github::Topic).to receive(:from_github).and_return(
        OpenStruct.new(stringify_keys: { name: 'test-topic' })
      )
      allow(GithubRepository).to receive(:upsert_all).and_return([ { 'id' => 1, 'github_id' => 'repo-123' } ])
      allow(Persistence::Helper).to receive(:insert_items_labels_if_any)
    end

    it 'persists repositories and their topics' do
      described_class.persist_many(repositories)

      expect(Github::Repository).to have_received(:from_github).with(repository)
      expect(Github::Topic).to have_received(:from_github)
      expect(GithubRepository).to have_received(:upsert_all)
      expect(Persistence::Helper).to have_received(:insert_items_labels_if_any).with(
        { 'repo-123' => [ { name: 'test-topic' } ] },
        [ { 'id' => 1, 'github_id' => 'repo-123' } ],
        :repositories
      )
    end

    context 'with invalid input' do
      it 'raises ArgumentError when repositories is nil' do
        expect {
          described_class.persist_many(nil)
        }.to raise_error(ArgumentError, "Repositories cannot be nil")
      end
    end
  end
end
