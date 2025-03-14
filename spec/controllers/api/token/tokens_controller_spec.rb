require 'rails_helper'

RSpec.describe Api::Token::TokensController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }

  before do
    authenticate_user(user)
  end

  describe '#usage' do
    before do
      # Create token usage logs
      create(:token_usage_log,
             user: user,
             usage_type: User.token_usage_levels[:personal],
             points_used: 10,
             points_remaining: 5000,
             created_at: 1.day.ago
      )

      create(:token_usage_log,
             user: user,
             usage_type: User.token_usage_levels[:contributed],
             points_used: 5,
             points_remaining: 4990,
             created_at: 2.days.ago
      )

      create(:token_usage_log,
             user: user,
             usage_type: User.token_usage_levels[:global_pool],
             points_used: 3,
             points_remaining: 4980,
             created_at: 5.days.ago
      )
    end

    it 'returns token usage statistics with daily breakdown' do
      get :usage

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('token_settings', 'total_stats', 'daily_usage')

      # Test token settings
      expect(json['data']['token_settings']).to include('token_usage_level')

      # Test total stats
      expect(json['data']['total_stats']).to include('total_queries', 'total_points_used',
                                                     'average_cost_per_query', 'usage_by_type')
      expect(json['data']['total_stats']['total_queries']).to eq(3)
      expect(json['data']['total_stats']['total_points_used']).to eq(18)

      # Test daily usage
      expect(json['data']['daily_usage']).to be_an(Array)
      expect(json['data']['daily_usage'].size).to be >= 5 # At least 5 days
    end

    it 'respects date range parameters' do
      get :usage, params: { start_date: 3.days.ago.to_date.to_s, end_date: 1.day.ago.to_date.to_s }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Only logs from the specified date range should be included in stats
      expect(json['data']['total_stats']['total_queries']).to eq(2)
      expect(json['data']['total_stats']['total_points_used']).to eq(15)
    end
  end

  describe '#update_settings' do
    it 'updates token usage level successfully' do
      expect(user.token_usage_level).to eq("personal")

      put :update_settings, params: { token_usage_level: 'global_pool' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['message']).to include('Token usage level updated successfully')
      expect(json['data']['token_usage_level']).to eq('global_pool')

      user.reload
      expect(user.token_usage_level).to eq('global_pool')
    end

    it 'rejects invalid token usage level' do
      put :update_settings, params: { token_usage_level: 'invalid_level' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)

      expect(json['error']['message']).to eq('Invalid token usage level')

      user.reload
      expect(user.token_usage_level).to eq('personal')
    end

    it 'handles update failure' do
      allow_any_instance_of(User).to receive(:update).and_return(false)
      allow_any_instance_of(User).to receive(:errors).and_return(double(full_messages: [ 'Update failed' ]))

      put :update_settings, params: { token_usage_level: 'contributed' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)

      expect(json['error']['message']).to eq('Failed')
      expect(json['error']['errors']).to eq([ 'Update failed' ])
    end
  end

  private

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
