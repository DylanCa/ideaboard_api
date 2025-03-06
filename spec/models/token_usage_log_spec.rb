require 'rails_helper'

RSpec.describe TokenUsageLog, type: :model do
  subject { create(:token_usage_log) }

  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should belong_to(:github_repository).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:usage_type) }
    it { should validate_presence_of(:points_used) }
    it { should validate_presence_of(:points_remaining) }

    it { should validate_numericality_of(:points_used).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:points_remaining).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:user_log) { create(:token_usage_log, user: create(:user)) }
    let!(:other_user_log) { create(:token_usage_log, user: create(:user)) }
    let!(:repo_log) { create(:token_usage_log, github_repository: create(:github_repository)) }
    let!(:other_repo_log) { create(:token_usage_log, github_repository: create(:github_repository)) }
    let!(:personal_log) { create(:token_usage_log, usage_type: User.token_usage_levels[:personal]) }
    let!(:contributed_log) { create(:token_usage_log, usage_type: User.token_usage_levels[:contributed]) }
    let!(:global_pool_log) { create(:token_usage_log, usage_type: User.token_usage_levels[:global_pool]) }

    describe '.by_user' do
      it 'returns logs for the specified user' do
        user = user_log.user
        expect(TokenUsageLog.by_user(user)).to include(user_log)
        expect(TokenUsageLog.by_user(user)).not_to include(other_user_log)
      end
    end

    describe '.by_repository' do
      it 'returns logs for the specified repository' do
        repo = repo_log.github_repository
        expect(TokenUsageLog.by_repository(repo)).to include(repo_log)
        expect(TokenUsageLog.by_repository(repo)).not_to include(other_repo_log)
      end
    end

    describe '.personal_queries' do
      it 'returns logs for personal queries' do
        expect(TokenUsageLog.personal_queries).to include(personal_log)
        expect(TokenUsageLog.personal_queries).not_to include(contributed_log)
        expect(TokenUsageLog.personal_queries).not_to include(global_pool_log)
      end
    end

    describe '.contributed_queries' do
      it 'returns logs for contributed queries' do
        expect(TokenUsageLog.contributed_queries).to include(contributed_log)
        expect(TokenUsageLog.contributed_queries).not_to include(personal_log)
        expect(TokenUsageLog.contributed_queries).not_to include(global_pool_log)
      end
    end

    describe '.global_pool_queries' do
      it 'returns logs for contributed queries' do
        expect(TokenUsageLog.global_pool_queries).to include(global_pool_log)
        expect(TokenUsageLog.global_pool_queries).not_to include(personal_log)
        expect(TokenUsageLog.global_pool_queries).not_to include(contributed_log)
      end
    end
  end
end
