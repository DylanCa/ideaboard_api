require 'rails_helper'

RSpec.describe Api::Auth::GithubController, type: :controller do
  describe "#callback" do
    let(:code) { "test_auth_code" }
    let(:github_user) do
      instance_double(
        Sawyer::Resource,
        id: 12345,
        login: 'test-user',
        email: 'test@example.com',
        avatar_url: 'https://github.com/avatar.png'
      )
    end
    let(:user) { create(:user, :with_github_account, :with_user_stat) }
    let(:jwt_token) { "test.jwt.token" }
    let(:jwt_token) { "test.jwt.token" }

    before do
      allow(controller).to receive(:params).and_return({ code: code })
    end

    context "when authentication is successful" do
      before do
        expect(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                       is_authenticated: true,
                                                                                       user: user
                                                                                     })

        expect(JwtService).to receive(:encode).with({
                                                      user_id: user.id,
                                                      github_username: user.github_account.github_username,
                                                      iat: kind_of(Integer)
                                                    }).and_return(jwt_token)
      end

      it "returns a JWT token and user data" do
        get :callback, params: { code: code }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to include(
                          "jwt_token" => jwt_token,
                          "user" => kind_of(Hash),
                          "github_account" => kind_of(Hash),
                          "user_stat" => kind_of(Hash)
                        )
      end

      it "includes the correct user data in the response" do
        get :callback, params: { code: code }

        json = JSON.parse(response.body)
        expect(json["user"]["id"]).to eq(user.id)
        expect(json["github_account"]["github_username"]).to eq(user.github_account.github_username)
        expect(json["user_stat"]).to be_present
      end
    end

    context "when authentication fails" do
      before do
        expect(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                       is_authenticated: false
                                                                                     })
      end

      it "raises an error" do
        expect {
          get :callback, params: { code: code }
        }.to raise_error(RuntimeError)
      end
    end

    context "with missing code parameter" do
      it "raises an error" do
        allow(controller).to receive(:params).and_return({})

        expect {
          get :callback
        }.to raise_error(RuntimeError)
      end
    end

    context "when OAuth service raises an error" do
      before do
        expect(Github::OauthService).to receive(:authenticate).with(code).and_raise(StandardError.new("OAuth error"))
      end

      it "propagates the error" do
        expect {
          get :callback, params: { code: code }
        }.to raise_error(StandardError, "OAuth error")
      end
    end

    context "when JWT encoding fails" do
      before do
        expect(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                       is_authenticated: true,
                                                                                       user: user
                                                                                     })

        expect(JwtService).to receive(:encode).and_raise(JWT::EncodeError.new("Encoding failed"))
      end

      it "propagates the JWT error" do
        expect {
          get :callback, params: { code: code }
        }.to raise_error(JWT::EncodeError, "Encoding failed")
      end
    end

    context "with payload generation" do
      before do
        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: true,
                                                                                      user: user
                                                                                    })

        allow(JwtService).to receive(:encode).and_return(jwt_token)
        allow(Time).to receive(:now).and_return(Time.at(1614556800))
      end

      it "generates a payload with the correct timestamp" do
        expect(JwtService).to receive(:encode).with(
          hash_including(iat: 1614556800)
        )

        get :callback, params: { code: code }
      end
    end
  end

  describe "error handling" do
    let(:code) { "test_auth_code" }

    context "when TODO section is reached" do
      before do
        allow(Github::OauthService).to receive(:authenticate).with(code).and_return({
                                                                                      is_authenticated: false
                                                                                    })
      end

      it "raises an error with pending TODO implementation" do
        expect {
          get :callback, params: { code: code }
        }.to raise_error(RuntimeError)
      end
    end
  end
end
