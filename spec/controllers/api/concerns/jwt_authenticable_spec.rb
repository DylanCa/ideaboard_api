require 'rails_helper'

RSpec.describe Api::Concerns::JwtAuthenticable, type: :controller do
  # Use a proper controller class instead of an anonymous controller
  class TestController < ActionController::Base
    include Api::Concerns::JwtAuthenticable

    def index
      render json: { status: 'ok' }
    end
  end

  controller(TestController) { }

  before do
    @routes.draw { get "index" => "test#index" }
  end

  describe "#authenticate_user!" do
    let(:user) { create(:user, :with_github_account) }
    let(:github_account) { user.github_account }
    let(:token_payload) do
      {
        "user_id" => user.id,
        "github_username" => github_account.github_username,
        "iat" => Time.now.to_i
      }
    end

    context "with valid token" do
      before do
        allow(JwtService).to receive(:decode).and_return(token_payload)
        @request.headers['Authorization'] = 'Bearer valid_token'
      end

      it "sets @current_user" do
        get :index
        expect(assigns(:current_user)).to eq(user)
      end

      it "allows access to the action" do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context "without Authorization header" do
      it "returns unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ "error" => "Unauthorized" })
      end
    end

    context "with invalid token" do
      before do
        allow(JwtService).to receive(:decode).and_raise(StandardError)
        @request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it "returns unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ "error" => "Unauthorized" })
      end
    end

    context "with mismatched user" do
      before do
        mismatched_payload = token_payload.merge("github_username" => "wrong_username")
        allow(JwtService).to receive(:decode).and_return(mismatched_payload)
        @request.headers['Authorization'] = 'Bearer token'
      end

      it "returns unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ "error" => "Unauthorized" })
      end
    end

    describe "#extract_token" do
      it "extracts token from Authorization header" do
        @request.headers['Authorization'] = 'Bearer test_token'
        expect(controller.send(:extract_token)).to eq("test_token")
      end

      it "returns nil when no Authorization header" do
        expect(controller.send(:extract_token)).to be_nil
      end
    end
  end
end
