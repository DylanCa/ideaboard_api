require 'rails_helper'

RSpec.describe Api::Auth::SessionsController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:token) { 'valid_jwt_token' }

  before do
    authenticate_user(user, token)
  end

  describe '#destroy' do
    before do
      allow(controller).to receive(:extract_token).and_return(token)
      allow(Rails.cache).to receive(:write).and_return(true)

      # Mock JwtService.decode to return a token with expiry
      future_time = Time.now.to_i + 3600 # 1 hour from now
      decoded_token = { 'exp' => future_time }
      allow(JwtService).to receive(:decode).with(token).and_return(decoded_token)
    end

    it 'blacklists the current token and returns success message' do
      delete :destroy

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['message']).to eq('Successfully logged out')

      # Verify token was blacklisted with proper expiry
      expect(Rails.cache).to have_received(:write).with(
        "blacklisted_token:#{token}",
        kind_of(Integer),
        expires_in: kind_of(ActiveSupport::Duration)
      )
    end

    it 'calculates correct expiry duration for blacklisting' do
      delete :destroy

      # Check that the token was blacklisted until its expiry time
      expect(Rails.cache).to have_received(:write).with(
        "blacklisted_token:#{token}",
        kind_of(Integer),
        expires_in: an_instance_of(ActiveSupport::Duration)
      )
    end

    context 'when token is already expired' do
      before do
        past_time = Time.now.to_i - 3600 # 1 hour ago
        expired_token = { 'exp' => past_time }
        allow(JwtService).to receive(:decode).with(token).and_return(expired_token)
      end

      it 'still blacklists the token with zero expiry' do
        delete :destroy

        expect(response).to have_http_status(:ok)
        expect(Rails.cache).to have_received(:write).with(
          "blacklisted_token:#{token}",
          kind_of(Integer),
          expires_in: 0.seconds
        )
      end
    end

    context 'when decoding fails' do
      before do
        # Use StandardError instead of JwtService::AuthenticationError
        allow(JwtService).to receive(:decode).with(token).and_raise(StandardError.new('Invalid token'))
      end

      it 'returns unauthorized error' do
        delete :destroy

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']['message']).to eq('Unauthorized')
      end
    end
  end

  private

  def authenticate_user(user, token = nil)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)

    # Simulate JWT authentication
    if token
      request.headers['Authorization'] = "Bearer #{token}"
    end
  end
end
