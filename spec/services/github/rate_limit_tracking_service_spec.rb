require 'rails_helper'

RSpec.describe Github::RateLimitTrackingService do
  describe '.extract_rate_limit_info' do
    let(:response) do
      OpenStruct.new(
        data: OpenStruct.new(
          rate_limit: OpenStruct.new(
            used: 100,
            remaining: 4900,
            limit: 5000,
            cost: 1,
            reset_at: "2025-02-28T12:00:00Z"
          )
        )
      )
    end

    it 'extracts and formats rate limit information' do
      result = described_class.extract_rate_limit_info(response)

      expect(result[:used]).to eq(100)
      expect(result[:remaining]).to eq(4900)
      expect(result[:limit]).to eq(5000)
      expect(result[:cost]).to eq(1)
      expect(result[:reset_at]).to eq("2025-02-28T12:00:00Z")
      expect(result[:percentage_used]).to eq(2.0) # (100/5000) * 100
    end
  end

  describe '.log_token_usage' do
    let(:user_id) { 1 }
    let(:repo) { create(:github_repository) }
    let(:usage_type) { :personal }
    let(:query) { 'UserData' }
    let(:variables) { { username: 'test-user' } }
    let(:rate_limit_info) do
      {
        cost: 1,
        remaining: 4900
      }
    end

    it 'creates a token usage log entry' do
      expect {
        described_class.log_token_usage(user_id, repo, usage_type, query, variables, rate_limit_info)
      }.to change(TokenUsageLog, :count).by(1)

      log = TokenUsageLog.last
      expect(log.user_id).to eq(user_id)
      expect(log.github_repository).to eq(repo)
      expect(log.query).to eq(query)
      expect(log.variables).to eq(variables)
      expect(log.usage_type).to eq(User.token_usage_levels[usage_type])
      expect(log.points_used).to eq(rate_limit_info[:cost])
      expect(log.points_remaining).to eq(rate_limit_info[:remaining])
    end
  end
end
