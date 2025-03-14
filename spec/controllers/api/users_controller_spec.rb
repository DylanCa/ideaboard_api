require 'rails_helper'

RSpec.describe Api::UsersController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }

  before do
    authenticate_user(user)
  end

  describe '#current_user' do
    before do
      mock_github_query('user_data')
      allow(Github::GraphqlService).to receive(:fetch_current_user_data).with(user).and_call_original
    end

    it 'fetches current user data from GitHub' do
      get :current_user

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).not_to be_nil
      expect(Github::GraphqlService).to have_received(:fetch_current_user_data).with(user)
    end
  end

  describe '#user_repos' do
    before do
      mock_github_query('user_repositories')
      allow(Github::GraphqlService).to receive(:fetch_current_user_repositories).with(user).and_call_original
    end

    it 'fetches user repositories from GitHub' do
      get :user_repos

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).not_to be_nil
      expect(Github::GraphqlService).to have_received(:fetch_current_user_repositories).with(user)
    end
  end

  describe '#fetch_user_contributions' do
    before do
      allow(Github::GraphqlService).to receive(:fetch_user_contributions).and_return({
                                                                                       contributions: 10,
                                                                                       prs_count: 5,
                                                                                       issues_count: 5
                                                                                     })
    end

    it 'fetches user contributions' do
      get :fetch_user_contributions

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('contributions' => 10, 'prs_count' => 5, 'issues_count' => 5)
      expect(Github::GraphqlService).to have_received(:fetch_user_contributions).with(user)
    end
  end

  describe '#profile' do
    it 'returns current user profile data' do
      get :profile

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('user', 'github_account', 'user_stat')
      expect(json['data']['user']['id']).to eq(user.id)
      expect(json['data']['github_account']['id']).to eq(user.github_account.id)
      expect(json['data']['user_stat']['id']).to eq(user.user_stat.id)
    end
  end

  describe '#update_profile' do
    let(:new_email) { 'new_email@example.com' }

    it 'updates user profile information' do
      put :update_profile, params: { user: { email: new_email } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['user']['email']).to eq(new_email)

      user.reload
      expect(user.email).to eq(new_email)
    end

    it 'updates token usage level' do
      put :update_profile, params: { user: { token_usage_level: 'global_pool' } }

      expect(response).to have_http_status(:ok)

      user.reload
      expect(user.token_usage_level).to eq('global_pool')
    end

    it 'handles validation errors' do
      allow_any_instance_of(User).to receive(:update).and_return(false)
      allow_any_instance_of(User).to receive(:errors).and_return(
        double(full_messages: [ 'Email is invalid' ])
      )

      put :update_profile, params: { user: { email: 'invalid' } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)

      expect(json['error']['message']).to eq('Failed')
      expect(json['error']['errors']).to eq([ 'Email is invalid' ])
    end
  end

  private

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
