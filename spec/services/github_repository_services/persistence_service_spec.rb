require 'rails_helper'

RSpec.describe GithubRepositoryServices::PersistenceService do
  describe '.update_repository_items' do
    let(:repo) { create(:github_repository) }
    let(:prs) { [ double('PR') ] }
    let(:issues) { [ double('Issue') ] }

    before do
      allow(Persistence::ItemPersistenceService).to receive(:persist_many)
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
    end

    context 'when both PRs and issues are provided' do
      it 'updates both pull requests and issues in a transaction' do
        described_class.update_repository_items(repo, prs, issues)

        expect(Persistence::ItemPersistenceService).to have_received(:persist_many).with(prs, repo, type: :prs)
        expect(Persistence::ItemPersistenceService).to have_received(:persist_many).with(issues, repo, type: :issues)
        expect(ActiveRecord::Base).to have_received(:transaction)
      end
    end

    context 'when only PRs are provided' do
      it 'only updates pull requests' do
        described_class.update_repository_items(repo, prs, [])

        expect(Persistence::ItemPersistenceService).to have_received(:persist_many).with(prs, repo, type: :prs)
        expect(Persistence::ItemPersistenceService).not_to have_received(:persist_many).with([], repo, type: :issues)
      end
    end

    context 'when only issues are provided' do
      it 'only updates issues' do
        described_class.update_repository_items(repo, [], issues)

        expect(Persistence::ItemPersistenceService).not_to have_received(:persist_many).with([], repo, type: :prs)
        expect(Persistence::ItemPersistenceService).to have_received(:persist_many).with(issues, repo, type: :issues)
      end
    end
  end

  describe '.update_repositories_content' do
    let(:repo1) { create(:github_repository, full_name: 'owner/repo1') }
    let(:repo2) { create(:github_repository, full_name: 'owner/repo2') }
    let(:repositories) { { 'owner/repo1' => repo1, 'owner/repo2' => repo2 } }
    let(:pr1) { double('PR1', repository: double(name_with_owner: 'owner/repo1')) }
    let(:pr2) { double('PR2', repository: double(name_with_owner: 'owner/repo2')) }
    let(:issue1) { double('Issue1', repository: double(name_with_owner: 'owner/repo1')) }
    let(:issue2) { double('Issue2', repository: double(name_with_owner: 'owner/repo2')) }
    let(:items) { {
      repositories: repositories,
      prs: [ pr1, pr2 ],
      issues: [ issue1, issue2 ]
    } }

    before do
      allow(described_class).to receive(:update_repository_items)
      allow(GithubRepositoryServices::ProcessingService).to receive(:filter_items_by_repo).and_call_original
    end

    it 'updates content for each repository with filtered items' do
      described_class.update_repositories_content(repositories, items)

      expect(GithubRepositoryServices::ProcessingService).to have_received(:filter_items_by_repo).with(items[:prs], 'owner/repo1')
      expect(GithubRepositoryServices::ProcessingService).to have_received(:filter_items_by_repo).with(items[:issues], 'owner/repo1')
      expect(GithubRepositoryServices::ProcessingService).to have_received(:filter_items_by_repo).with(items[:prs], 'owner/repo2')
      expect(GithubRepositoryServices::ProcessingService).to have_received(:filter_items_by_repo).with(items[:issues], 'owner/repo2')

      expect(described_class).to have_received(:update_repository_items).twice
    end
  end
end
