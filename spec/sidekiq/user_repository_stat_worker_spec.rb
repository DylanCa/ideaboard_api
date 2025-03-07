require 'rails_helper'

RSpec.describe UserRepositoryStatWorker do
  describe '#execute' do
    let(:user) { create(:user, :with_github_account) }
    let(:user_id) { user.id }
    let(:repo) { create(:github_repository) }
    let(:github_repository_id) { repo.id }
    let(:username) { user.github_account.github_username }

    before do
      allow(User).to receive(:find_by).with(id: user_id).and_return(user)
    end

    context 'with a specific repository' do
      let(:merged_pr) { create(:pull_request, github_repository: repo, author_username: username, merged_at: Time.current) }
      let(:open_pr) { create(:pull_request, github_repository: repo, author_username: username, merged_at: nil) }
      let(:closed_pr) { create(:pull_request, github_repository: repo, author_username: username, merged_at: nil, closed_at: Time.current) }
      let(:closed_issue) { create(:issue, github_repository: repo, author_username: username, closed_at: Time.current) }
      let(:open_issue) { create(:issue, github_repository: repo, author_username: username, closed_at: nil) }

      before do
        # Set up test data
        merged_pr
        open_pr
        closed_pr
        closed_issue
        open_issue

        allow(PullRequest).to receive(:where).and_return([ merged_pr, open_pr, closed_pr ])
        allow(Issue).to receive(:where).and_return([ closed_issue, open_issue ])
      end

      it 'calculates and updates statistics for the specific repository' do
        expect {
          subject.execute(user_id, github_repository_id)
        }.to change(UserRepositoryStat, :count).by(1)

        stats = UserRepositoryStat.last
        expect(stats.user_id).to eq(user_id)
        expect(stats.github_repository_id).to eq(github_repository_id)
        expect(stats.opened_prs_count).to eq(3)
        expect(stats.merged_prs_count).to eq(1)
        expect(stats.closed_prs_count).to eq(1)
        expect(stats.issues_opened_count).to eq(2)
        expect(stats.issues_closed_count).to eq(1)
        expect(stats.first_contribution_at).not_to be_nil
        expect(stats.last_contribution_at).not_to be_nil
      end

      context 'when stats already exist' do
        let!(:existing_stats) { create(:user_repository_stat, user: user, github_repository: repo) }

        it 'updates existing statistics' do
          expect {
            subject.execute(user_id, github_repository_id)
          }.not_to change(UserRepositoryStat, :count)

          existing_stats.reload
          expect(existing_stats.opened_prs_count).to eq(3)
          expect(existing_stats.merged_prs_count).to eq(1)
        end
      end
    end

    context 'without a specific repository' do
      let(:repo1) { create(:github_repository) }
      let(:repo2) { create(:github_repository) }

      before do
        # Create PRs and issues across multiple repositories
        create(:pull_request, github_repository: repo1, author_username: username)
        create(:pull_request, github_repository: repo2, author_username: username)
        create(:issue, github_repository: repo1, author_username: username)
      end

      it 'processes statistics for all repositories' do
        result = subject.execute(user_id)

        expect(result).to include(
                            user_id: user_id,
                            username: username,
                            completed: true
                          )
      end

      it 'creates statistics for each repository' do
        expect {
          subject.execute(user_id)
        }.to change(UserRepositoryStat, :count).by(2)
      end
    end

    context 'when user does not exist' do
      before do
        allow(User).to receive(:find_by).with(id: user_id).and_return(nil)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
      end
    end

    context 'when user has no github account' do
      before do
        user.github_account = nil
        allow(User).to receive(:find_by).with(id: user_id).and_return(user)
      end

      it 'returns nil without processing' do
        result = subject.execute(user_id)

        expect(result).to be_nil
      end
    end
  end

  describe 'contribution streak calculation' do
    it 'calculates streak correctly with consecutive dates' do
      dates = [
        DateTime.now.utc.beginning_of_day - 3.days,
        DateTime.now.utc.beginning_of_day - 2.days,
        DateTime.now.utc.beginning_of_day - 1.day
      ]

      streak = subject.send(:calculate_streak, dates)
      expect(streak).to eq(3)
    end

    it 'calculates streak correctly with gaps in dates' do
      dates = [
        DateTime.now.utc.beginning_of_day - 5.days,
        DateTime.now.utc.beginning_of_day - 3.days,
        DateTime.now.utc.beginning_of_day - 1.day
      ]

      streak = subject.send(:calculate_streak, dates)
      expect(streak).to eq(1)
    end

    it 'returns 0 for empty dates array' do
      streak = subject.send(:calculate_streak, [])
      expect(streak).to eq(0)
    end
  end
end
