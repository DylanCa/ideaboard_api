require 'rails_helper'

RSpec.describe ItemsFetcherWorker do
  describe '#execute' do
    let(:repo) { create(:github_repository, full_name: 'owner/repo') }
    let(:repo_id) { repo.id }
    let(:prs) { [ double('PR1'), double('PR2') ] }
    let(:issues) { [ double('Issue1'), double('Issue2') ] }

    before do
      allow(GithubRepository).to receive(:find_by).with(id: repo_id).and_return(repo)
      allow(GithubRepositoryServices::QueryService).to receive(:fetch_items).and_return(prs, issues)
      allow(GithubRepositoryServices::PersistenceService).to receive(:update_repository_items)
    end

    context 'when fetching both prs and issues' do
      it 'fetches and updates both types of items' do
        result = subject.execute(repo_id, 'both')

        expect(GithubRepository).to have_received(:find_by).with(id: repo_id)

        # Verify PR fetch and update
        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_items).with(
          repo.full_name, item_type: :prs
        )

        # Verify Issue fetch and update
        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_items).with(
          repo.full_name, item_type: :issues
        )

        # Verify twice for both PRs and issues
        expect(GithubRepositoryServices::PersistenceService).to have_received(:update_repository_items).twice

        expect(result).to include(
                            repository_id: repo_id,
                            full_name: 'owner/repo',
                            item_type: 'both',
                            prs_count: 2,
                            issues_count: 2
                          )
      end
    end

    context 'when fetching only prs' do
      it 'only fetches and updates prs' do
        result = subject.execute(repo_id, 'prs')

        expect(GithubRepository).to have_received(:find_by).with(id: repo_id)

        # Verify PR fetch and update
        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_items).with(
          repo.full_name, item_type: :prs
        )

        # Verify Issue fetch and update was not called
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_items).with(
          repo.full_name, item_type: :issues
        )

        # Verify once for PRs only
        expect(GithubRepositoryServices::PersistenceService).to have_received(:update_repository_items).once

        expect(result).to include(
                            repository_id: repo_id,
                            full_name: 'owner/repo',
                            item_type: 'prs',
                            prs_count: 2,
                            issues_count: 0
                          )
      end
    end

    context 'when fetching only issues' do
      it 'only fetches and updates issues' do
        result = subject.execute(repo_id, 'issues')

        expect(GithubRepository).to have_received(:find_by).with(id: repo_id)

        # Verify PR fetch and update was not called
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_items).with(
          repo.full_name, item_type: :prs
        )

        # Verify Issue fetch and update
        expect(GithubRepositoryServices::QueryService).to have_received(:fetch_items).with(
          repo.full_name, item_type: :issues
        )

        # Verify once for issues only
        expect(GithubRepositoryServices::PersistenceService).to have_received(:update_repository_items).once

        expect(result).to include(
                            repository_id: repo_id,
                            full_name: 'owner/repo',
                            item_type: 'issues',
                            prs_count: 0,
                            issues_count: 2
                          )
      end
    end

    context 'when repository is not found' do
      before do
        allow(GithubRepository).to receive(:find_by).with(id: repo_id).and_return(nil)
      end

      it 'returns nil without processing' do
        result = subject.execute(repo_id, 'both')

        expect(result).to be_nil
        expect(GithubRepositoryServices::QueryService).not_to have_received(:fetch_items)
        expect(GithubRepositoryServices::PersistenceService).not_to have_received(:update_repository_items)
      end
    end
  end
end
