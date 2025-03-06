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
    let(:repo_id) { 1 }
    let(:label_name) { 'bug' }
    let(:label) { create(:label, name: label_name, github_repository_id: repo_id) }

    describe '.get_label_by_name' do
      it 'returns nil when label is not cached' do
        expect(described_class.get_label_by_name(label_name, repo_id)).to be_nil
      end

      it 'returns the label when it is cached' do
        described_class.label_cache["#{label_name}_#{repo_id}"] = label
        expect(described_class.get_label_by_name(label_name, repo_id)).to eq(label)
      end
    end

    describe '.preload_labels' do
      context 'when labels exist in database' do
        before do
          label  # Create the label
          allow(Label).to receive(:where).and_return([ label ])
        end

        it 'loads and caches existing labels' do
          described_class.preload_labels([ label_name ], repo_id)

          cached_label = described_class.get_label_by_name(label_name, repo_id)
          expect(cached_label).not_to be_nil
          expect(cached_label.name).to eq(label_name)
        end
      end

      context 'when labels do not exist in database' do
        let(:label_name) { 'new-label' }

        before do
          allow(Label).to receive(:where).and_return([])
          allow(Label).to receive(:insert_all).and_return(
            OpenStruct.new(rows: [ [ 2, label_name, repo_id ] ])
          )
        end

        it 'creates and caches new labels' do
          described_class.preload_labels([ label_name ], repo_id)

          expect(Label).to have_received(:insert_all)

          cached_label = described_class.get_label_by_name(label_name, repo_id)
          expect(cached_label).not_to be_nil
          expect(cached_label.name).to eq(label_name)
        end
      end

      context 'with invalid inputs' do
        it 'handles nil label_names' do
          expect {
            described_class.preload_labels(nil, repo_id)
          }.not_to raise_error
        end

        it 'handles nil repo_id' do
          expect {
            described_class.preload_labels([ label_name ], nil)
          }.not_to raise_error
        end

        it 'handles empty label_names array' do
          expect {
            described_class.preload_labels([], repo_id)
          }.not_to raise_error
        end
      end
    end

    describe '.reset_cache' do
      before do
        described_class.label_cache["#{label_name}_#{repo_id}"] = label
      end

      it 'clears the label cache' do
        expect(described_class.label_cache).not_to be_empty
        described_class.reset_cache
        expect(described_class.label_cache).to be_empty
      end
    end
  end
end
