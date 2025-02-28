require 'rails_helper'

RSpec.describe Github::GraphqlService do
  describe '.fetch_current_user_data' do
    let(:user) { create(:user, :with_github_account, :with_access_token) }

    it 'fetches user data from GitHub' do
      mock_github_query(:user_data)

      result = described_class.fetch_current_user_data(user)

      expect(result.login).to eq('testuser')
      expect(result.email).to eq('test@example.com')
      expect(result.database_id).to eq(12345)
    end
  end
end
