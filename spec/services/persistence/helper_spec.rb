require 'rails_helper'

RSpec.describe Persistence::Helper do
  before do
    described_class.reset_cache
  end

  describe '.insert_items_labels_if_any' do
    context 'with pull request labels' do
      let(:labels) { { 'pr-123' => [ { name: 'bug' }, { name: 'enhancement' } ] } }
      let(:inserted_items) { [ { 'id' => 1, 'github_id' => 'pr-123' } ] }

      before do
        allow(described_class).to receive(:insert_items_metadata)
      end

      it 'calls insert_items_metadata with correct parameters for PRs' do
        described_class.insert_items_labels_if_any(labels, inserted_items, :prs)

        expect(described_class).to have_received(:insert_items_metadata).with(
          labels,
          inserted_items,
          Label,
          PullRequestLabel,
          :pull_request_id,
          :label_id
        )
      end
    end

    context 'with issue labels' do
      let(:labels) { { 'issue-123' => [ { name: 'bug' }, { name: 'enhancement' } ] } }
      let(:inserted_items) { [ { 'id' => 1, 'github_id' => 'issue-123' } ] }

      before do
        allow(described_class).to receive(:insert_items_metadata)
      end

      it 'calls insert_items_metadata with correct parameters for issues' do
        described_class.insert_items_labels_if_any(labels, inserted_items, :issues)

        expect(described_class).to have_received(:insert_items_metadata).with(
          labels,
          inserted_items,
          Label,
          IssueLabel,
          :issue_id,
          :label_id
        )
      end
    end

    context 'with repository topics' do
      let(:topics) { { 'repo-123' => [ { name: 'ruby' }, { name: 'api' } ] } }
      let(:inserted_items) { [ { 'id' => 1, 'github_id' => 'repo-123' } ] }

      before do
        allow(described_class).to receive(:insert_items_metadata)
      end

      it 'calls insert_items_metadata with correct parameters for repositories' do
        described_class.insert_items_labels_if_any(topics, inserted_items, :repositories)

        expect(described_class).to have_received(:insert_items_metadata).with(
          topics,
          inserted_items,
          Topic,
          GithubRepositoryTopic,
          :github_repository_id,
          :topic_id
        )
      end
    end

    context 'with invalid type' do
      let(:labels) { { 'item-123' => [ { name: 'bug' } ] } }
      let(:inserted_items) { [ { 'id' => 1, 'github_id' => 'item-123' } ] }

      it 'raises an error for unknown types' do
        expect {
          described_class.insert_items_labels_if_any(labels, inserted_items, :unknown)
        }.to raise_error(RuntimeError)
      end
    end
  end

  describe 'label caching' do
    let(:repo) { create(:github_repository) }
    let(:label_name) { 'bug' }
    let(:label) { create(:label, name: label_name, github_repository: repo) }

    describe '.get_label_by_name' do
      it 'returns nil when label is not cached' do
        expect(described_class.get_label_by_name(label_name, repo.id)).to be_nil
      end

      it 'returns the label when it is cached' do
        described_class.label_cache["#{label_name}_#{repo.id}"] = label
        expect(described_class.get_label_by_name(label_name, repo.id)).to eq(label)
      end
    end

    describe '.preload_labels' do
      context 'when labels exist in database' do
        before do
          label  # Create the label
          allow(Label).to receive(:where).and_return([ label ])
        end

        it 'loads and caches existing labels' do
          described_class.preload_labels([ label_name ], repo.id)

          cached_label = described_class.get_label_by_name(label_name, repo.id)
          expect(cached_label).not_to be_nil
          expect(cached_label.name).to eq(label_name)
        end
      end

      context 'when labels do not exist in database' do
        let(:label_name) { 'new-label' }

        before do
          allow(Label).to receive(:where).and_return([])
          allow(Label).to receive(:insert_all).and_return(
            OpenStruct.new(rows: [ [ 2, label_name, repo.id ] ])
          )
        end

        it 'creates and caches new labels' do
          described_class.preload_labels([ label_name ], repo.id)

          expect(Label).to have_received(:insert_all)

          cached_label = described_class.get_label_by_name(label_name, repo.id)
          expect(cached_label).not_to be_nil
          expect(cached_label.name).to eq(label_name)
        end
      end

      context 'with invalid inputs' do
        it 'handles nil label_names' do
          expect {
            described_class.preload_labels(nil, repo.id)
          }.not_to raise_error
        end

        it 'handles nil repo.id' do
          expect {
            described_class.preload_labels([ label_name ], nil)
          }.not_to raise_error
        end

        it 'handles empty label_names array' do
          expect {
            described_class.preload_labels([], repo.id)
          }.not_to raise_error
        end
      end
    end

    describe '.reset_cache' do
      before do
        described_class.label_cache["#{label_name}_#{repo.id}"] = label
      end

      it 'clears the label cache' do
        expect(described_class.label_cache).not_to be_empty
        described_class.reset_cache
        expect(described_class.label_cache).to be_empty
      end
    end
  end

  describe '.insert_items_metadata' do
    context 'when items_data is empty' do
      it 'returns early without processing' do
        expect(described_class.send(:insert_items_metadata, {}, [], Label, PullRequestLabel, :pull_request_id, :label_id)).to be_nil
      end
    end

    context 'with topics' do
      let(:repo) { create(:github_repository) }
      let(:topics_data) { { 'repo-123' => [ { name: 'ruby' }, { name: 'api' } ] } }
      let(:inserted_items) { [ { 'id' => repo.id, 'github_id' => 'repo-123' } ] }

      it 'creates topics and join records in the database' do
        # Ensure no existing records interfere
        Topic.delete_all
        GithubRepositoryTopic.delete_all

        # Call the method with actual database interaction
        described_class.send(:insert_items_metadata,
                             topics_data,
                             inserted_items,
                             Topic,
                             GithubRepositoryTopic,
                             :github_repository_id,
                             :topic_id
        )

        # Verify topics were created
        expect(Topic.count).to eq(2)
        expect(Topic.pluck(:name)).to match_array([ 'ruby', 'api' ])

        # Verify join records were created
        expect(GithubRepositoryTopic.count).to eq(2)

        # Verify join records link correct topics to repository
        ruby_topic = Topic.find_by(name: 'ruby')
        api_topic = Topic.find_by(name: 'api')

        expect(GithubRepositoryTopic.exists?(
          github_repository_id: repo.id,
          topic_id: ruby_topic.id
        )).to be_truthy

        expect(GithubRepositoryTopic.exists?(
          github_repository_id: repo.id,
          topic_id: api_topic.id
        )).to be_truthy
      end
    end
  end

  describe '.preload_labels' do
    context 'when label insertion fails' do
      let(:repo) { create(:github_repository) }
      let(:label_name) { 'new-label' }

      before do
        allow(Label).to receive(:where).and_return([])
        allow(Label).to receive(:insert_all).and_raise(StandardError.new("Test error"))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs errors during label creation' do
        described_class.preload_labels([ label_name ], repo.id)
        expect(Rails.logger).to have_received(:error).with(/Error creating labels/)
      end
    end
  end
end
