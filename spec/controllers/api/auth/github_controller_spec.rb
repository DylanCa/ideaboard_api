require 'rails_helper'

RSpec.describe Api::Auth::GithubController, type: :controller do
  describe '#initiate' do
    it 'generates OAuth state and returns GitHub OAuth URL' do
      # Setup random state
      secure_random = SecureRandom.hex(24)
      allow(SecureRandom).to receive(:hex).with(24).and_return(secure_random)
      allow(Rails.cache).to receive(:write).and_return(true)

      get :initiate

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to have_key('redirect_url')
      expect(json['data']['redirect_url']).to include('https://github.com/login/oauth/authorize')
      expect(json['data']['redirect_url']).to include("state=#{secure_random}")
      expect(json['data']['redirect_url']).to include("client_id=")
      expect(json['data']['redirect_url']).to include("scope=#{CGI.escape("user:email,read:user,repo")}")

      # Verify state was stored in cache
      expect(Rails.cache).to have_received(:write).with(
        "oauth_state:#{secure_random}",
        { created_at: kind_of(Time) },
        expires_in: 10.minutes
      )
    end
  end

  describe '#callback' do
    let(:code) { 'test_auth_code' }
    let(:state) { 'test_state' }
    let(:user) { create(:user, :with_github_account, :with_user_stat) }
    let(:jwt_token) { 'test.jwt.token' }
    let(:stored_state) { { created_at: 5.minutes.ago } }

    context 'with valid state and successful authentication' do
      before do
        allow(Rails.cache).to receive(:read).with("oauth_state:#{state}").and_return(stored_state)
        allow(Rails.cache).to receive(:delete).with("oauth_state:#{state}").and_return(true)

        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: true,
                                                                                      user: user
                                                                                    })

        allow(JwtService).to receive(:encode).with(
          hash_including(
            user_id: user.id,
            github_username: user.github_account.github_username,
            iat: kind_of(Integer)
          )
        ).and_return(jwt_token)

        allow(Time).to receive(:now).and_return(Time.at(1614556800))
      end

      it 'authenticates user and returns JWT token with user data' do
        get :callback, params: { code: code, state: state }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']).to include('jwt_token', 'user', 'github_account', 'user_stat')
        expect(json['data']['jwt_token']).to eq(jwt_token)
        expect(json['data']['user']['id']).to eq(user.id)
        expect(json['data']['github_account']['github_username']).to eq(user.github_account.github_username)

        # Verify expected method calls
        expect(Rails.cache).to have_received(:read).with("oauth_state:#{state}")
        expect(Rails.cache).to have_received(:delete).with("oauth_state:#{state}")
        expect(Github::OauthService).to have_received(:authenticate).with(code)
        expect(JwtService).to have_received(:encode).with(
          hash_including(iat: 1614556800)
        )
      end
    end

    context 'with invalid state' do
      before do
        allow(Rails.cache).to receive(:read).with("oauth_state:#{state}").and_return(nil)
      end

      it 'returns unauthorized error' do
        get :callback, params: { code: code, state: state }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)

        expect(json['error']['message']).to eq('Invalid OAuth state')
      end
    end

    context 'when authentication fails' do
      before do
        allow(Rails.cache).to receive(:read).with("oauth_state:#{state}").and_return(stored_state)
        allow(Rails.cache).to receive(:delete).with("oauth_state:#{state}").and_return(true)

        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: false
                                                                                    })
      end

      it 'returns unauthorized error' do
        get :callback, params: { code: code, state: state }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)

        expect(json['error']['message']).to eq('Authentication failed')
      end
    end

    context 'when OAuth service raises an error' do
      before do
        allow(Rails.cache).to receive(:read).with("oauth_state:#{state}").and_return(stored_state)
        allow(Rails.cache).to receive(:delete).with("oauth_state:#{state}").and_return(true)

        allow(Github::OauthService).to receive(:authenticate).with(code).and_raise(StandardError.new('OAuth error'))
      end

      it 'propagates the error' do
        expect {
          get :callback, params: { code: code, state: state }
        }.to raise_error(StandardError, 'OAuth error')
      end
    end

    context 'when JWT encoding fails' do
      before do
        allow(Rails.cache).to receive(:read).with("oauth_state:#{state}").and_return(stored_state)
        allow(Rails.cache).to receive(:delete).with("oauth_state:#{state}").and_return(true)

        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: true,
                                                                                      user: user
                                                                                    })

        allow(JwtService).to receive(:encode).and_raise(JWT::EncodeError.new('Encoding failed'))
      end

      it 'propagates the JWT error' do
        expect {
          get :callback, params: { code: code, state: state }
        }.to raise_error(JWT::EncodeError, 'Encoding failed')
      end
    end

    context 'without state parameter' do
      it 'processes the request without state verification' do
        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: true,
                                                                                      user: user
                                                                                    })

        allow(JwtService).to receive(:encode).and_return(jwt_token)

        get :callback, params: { code: code }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['jwt_token']).to eq(jwt_token)
      end
    end

    context 'with missing code parameter' do
      it 'returns a parameter missing error' do
        allow(controller).to receive(:params).and_return({})

        get :callback

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)

        expect(json['error']).to eq({ "message" => "Authentication failed", "status" => 401 })
      end
    end
  end
end
