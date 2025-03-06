require 'rails_helper'

RSpec.describe RateLimitLog, type: :model do
  describe 'associations' do
    it { should belong_to(:token_owner) }
  end

  describe 'validations' do
    it { should validate_presence_of(:query_name) }
    it { should validate_presence_of(:cost) }
    it { should validate_presence_of(:remaining_points) }
    it { should validate_presence_of(:reset_at) }
    it { should validate_presence_of(:executed_at) }

    it { should validate_numericality_of(:cost).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:remaining_points).is_greater_than_or_equal_to(0) }

    describe 'reset_at validation' do
      it 'ensures reset_at is after executed_at' do
        log = build(:rate_limit_log, executed_at: Time.current, reset_at: 1.hour.ago)
        expect(log).not_to be_valid
        expect(log.errors[:reset_at]).to include("must be greater than executed_at")
      end
    end
  end

  describe 'scopes' do
    let!(:recent_log) { create(:rate_limit_log, executed_at: 1.hour.ago) }
    let!(:old_log) { create(:rate_limit_log, executed_at: 1.day.ago) }
    let(:user) { create(:user) }
    let!(:user_log) { create(:rate_limit_log, token_owner: user) }
    let!(:high_cost_log) { create(:rate_limit_log, cost: 15) }
    let!(:low_cost_log) { create(:rate_limit_log, cost: 5) }
    let!(:low_points_log) { create(:rate_limit_log, remaining_points: 500) }
    let!(:high_points_log) { create(:rate_limit_log, remaining_points: 4500) }

    describe '.recent' do
      it 'returns logs ordered by execution time in descending order' do
        expect(RateLimitLog.recent.first).to eq(recent_log)
        expect(RateLimitLog.recent.last).to eq(old_log)
      end
    end

    describe '.by_owner' do
      it 'returns logs for the specified owner' do
        expect(RateLimitLog.by_owner(user)).to include(user_log)
        expect(RateLimitLog.by_owner(user)).not_to include(recent_log) # Assuming different owner
      end
    end

    describe '.by_query' do
      let!(:user_query_log) { create(:rate_limit_log, query_name: 'UserData') }
      let!(:repo_query_log) { create(:rate_limit_log, query_name: 'RepositoryData') }

      it 'returns logs for the specified query' do
        expect(RateLimitLog.by_query('UserData')).to include(user_query_log)
        expect(RateLimitLog.by_query('UserData')).not_to include(repo_query_log)
      end
    end

    describe '.costly' do
      it 'returns logs with cost greater than 10' do
        expect(RateLimitLog.costly).to include(high_cost_log)
        expect(RateLimitLog.costly).not_to include(low_cost_log)
      end
    end

    describe '.low_points_remaining' do
      it 'returns logs with less than 1000 remaining points' do
        expect(RateLimitLog.low_points_remaining).to include(low_points_log)
        expect(RateLimitLog.low_points_remaining).not_to include(high_points_log)
      end
    end
  end
end
