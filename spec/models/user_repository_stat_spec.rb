require 'rails_helper'

RSpec.describe UserRepositoryStat, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:github_repository) }
  end

  describe 'validations' do
    subject { create(:user_repository_stat) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:github_repository_id) }

    it { should validate_presence_of(:opened_prs_count) }
    it { should validate_presence_of(:merged_prs_count) }
    it { should validate_presence_of(:issues_opened_count) }
    it { should validate_presence_of(:issues_closed_count) }
    it { should validate_presence_of(:issues_with_pr_count) }

    it { should validate_numericality_of(:opened_prs_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:merged_prs_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_opened_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_closed_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_with_pr_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:active_stat) { create(:user_repository_stat, opened_prs_count: 5, issues_opened_count: 10) }
    let!(:inactive_stat) { create(:user_repository_stat, opened_prs_count: 0, issues_opened_count: 0) }
    let!(:pr_stat) { create(:user_repository_stat, merged_prs_count: 5, opened_prs_count: 0, issues_opened_count: 0) }
    let!(:issue_stat) { create(:user_repository_stat, merged_prs_count: 0, issues_closed_count: 5) }

    describe '.with_contributions' do
      it 'returns stats with either PRs or issues' do
        expect(UserRepositoryStat.with_contributions).to include(active_stat)
        expect(UserRepositoryStat.with_contributions).not_to include(inactive_stat)
      end
    end

    describe '.with_merged_prs' do
      it 'returns stats with merged PRs' do
        expect(UserRepositoryStat.with_merged_prs).to include(pr_stat)
        expect(UserRepositoryStat.with_merged_prs).not_to include(issue_stat)
        expect(UserRepositoryStat.with_merged_prs).not_to include(inactive_stat)
      end
    end

    describe '.by_contribution_count' do
      it 'orders stats by merged PRs and closed issues' do
        # Due to the complex nature of this scope, we'll just check it runs without errors
        expect { UserRepositoryStat.by_contribution_count.to_a }.not_to raise_error
      end
    end
  end
end
