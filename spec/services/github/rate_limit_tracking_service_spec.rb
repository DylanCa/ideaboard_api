require 'rails_helper'

RSpec.describe Github::RateLimitTrackingService do
  describe '.extract_rate_limit_info' do
    # Use fixture data instead of manual struct creation
    let(:rate_limit_response) { mock_github_query('user_data') }

    it 'extracts and formats rate limit information' do
      result = described_class.extract_rate_limit_info(rate_limit_response)

      expect(result[:used]).to be_a(Integer)
      expect(result[:remaining]).to be_a(Integer)
      expect(result[:limit]).to be_a(Integer)
      expect(result[:cost]).to be_a(Integer)
      expect(result[:percentage_used]).to be_a(Float)
    end
  end

  describe '.log_token_usage' do
    let(:user) { create(:user) }
    let(:user_id) { user.id }
    let(:repo) { create(:github_repository) }
    let(:usage_type) { :personal }
    let(:query) { 'UserData' }
    let(:variables) { { username: 'test-user' } }
    let(:rate_limit_info) { { cost: 1, remaining: 4900 } }

    it 'creates a token usage log entry in the database' do
      expect {
        described_class.log_token_usage(user_id, repo, usage_type, query, variables, rate_limit_info)
      }.to change(TokenUsageLog, :count).by(1)

      log = TokenUsageLog.last
      expect(log.user_id).to eq(user_id)
      expect(log.github_repository_id).to eq(repo.id)
      expect(log.usage_type).to eq(User.token_usage_levels[usage_type])
    end
  end
end
