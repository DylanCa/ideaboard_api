require 'rails_helper'

RSpec.describe TokenUsageLog, type: :model do
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
    let!(:recent_log) { create(:token_usage_log, created_at: 1.hour.ago) }
    let!(:old_log) { create(:token_usage_log, created_at: 1.week.ago) }
    let!(:user_log) { create(:token_usage_log, user: create(:user)) }
    let!(:other_user_log) { create(:token_usage_log, user: create(:user)) }
    let!(:repo_log) { create(:token_usage_log, github_repository: create(:github_repository)) }
    let!(:other_repo_log) { create(:token_usage_log, github_repository: create(:github_repository)) }
    let!(:installation_log) { create(:token_usage_log, usage_type: :installation) }
    let!(:personal_log) { create(:token_usage_log, usage_type: :personal) }

    describe '.recent' do
      it 'returns logs ordered by creation time in descending order' do
        expect(TokenUsageLog.recent.first).to eq(recent_log)
        expect(TokenUsageLog.recent.last).to eq(old_log)
      end
    end

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

    describe '.installation_queries' do
      it 'returns logs for installation queries' do
        expect(TokenUsageLog.installation_queries).to include(installation_log)
        expect(TokenUsageLog.installation_queries).not_to include(personal_log)
      end
    end

    describe '.user_queries' do
      it 'returns logs for non-installation queries' do
        expect(TokenUsageLog.user_queries).to include(personal_log)
        expect(TokenUsageLog.user_queries).not_to include(installation_log)
      end
    end
  end
end
