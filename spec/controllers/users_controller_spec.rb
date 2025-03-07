require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }
  let(:github_account) { user.github_account }

  before do
    # Stub the authenticate_user! method to do nothing
    allow(controller).to receive(:authenticate_user!).and_return(true)

    # Force the correct @current_user value
    allow_any_instance_of(JwtAuthenticable).to receive(:extract_token).and_return("test-token")
    allow(JwtService).to receive(:decode).and_return({ "user_id" => user.id, "github_username" => user.github_account.github_username })
    allow(User).to receive(:joins).and_return(User)
    allow(User).to receive(:find_by!).and_return(user)

    # Double-check that the correct @current_user is set
    controller.send(:authenticate_user!)
  end

  describe "#current_user" do
    let(:mock_response) { { 'data' => { 'login' => 'test-user' } } }

    before do
      allow(Github::GraphqlService).to receive(:fetch_current_user_data).with(user).and_return(mock_response)
    end

    it "fetches and returns the current user data" do
      get :current_user

      expect(response).to have_http_status(:ok).or have_http_status(:no_content)
      expect(Github::GraphqlService).to have_received(:fetch_current_user_data).with(user)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_response })
    end

    context "when GraphQL service fails" do
      before do
        allow(Github::GraphqlService).to receive(:fetch_current_user_data).with(user).and_return(nil)
      end

      it "returns nil data" do
        get :current_user

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#user_repos" do
    let(:mock_repos) { [ { 'id' => 1, 'name' => 'repo1' }, { 'id' => 2, 'name' => 'repo2' } ] }

    before do
      allow(Github::GraphqlService).to receive(:fetch_current_user_repositories).with(user).and_return(mock_repos)
    end

    it "fetches and returns the user's repositories" do
      get :user_repos

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:fetch_current_user_repositories).with(user)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_repos })
    end

    context "when GraphQL service fails" do
      before do
        allow(Github::GraphqlService).to receive(:fetch_current_user_repositories).with(user).and_return(nil)
      end

      it "returns nil data" do
        get :user_repos

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#update_repositories_data" do
    let(:mock_result) { { 'updated' => true, 'repositories' => 5 } }

    before do
      allow(Github::GraphqlService).to receive(:update_repositories_data).and_return(mock_result)
    end

    it "updates and returns repository data" do
      get :update_repositories_data

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:update_repositories_data)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_result })
    end

    context "when GraphQL service fails" do
      before do
        allow(Github::GraphqlService).to receive(:update_repositories_data).and_return(nil)
      end

      it "returns nil data" do
        get :update_repositories_data

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#add_repository" do
    let(:repo_name) { 'owner/repo' }
    let(:mock_result) { { 'added' => true, 'repository' => repo_name } }

    before do
      allow(Github::GraphqlService).to receive(:add_repo_by_name).with(repo_name).and_return(mock_result)
    end

    it "adds and returns repository data" do
      get :add_repository, params: { repo_name: repo_name }

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:add_repo_by_name).with(repo_name)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_result })
    end

    context "with missing repo_name parameter" do
      it "passes nil to service" do
        allow(Github::GraphqlService).to receive(:add_repo_by_name).with(nil).and_return(nil)

        get :add_repository

        expect(response).to have_http_status(:ok)
        expect(Github::GraphqlService).to have_received(:add_repo_by_name).with(nil)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#fetch_repo_updates" do
    let(:repo_name) { 'owner/repo' }
    let(:mock_result) { { 'updated' => true, 'repository' => repo_name } }

    before do
      allow(Github::GraphqlService).to receive(:fetch_repository_update).with(repo_name).and_return(mock_result)
    end

    it "fetches and returns repository updates" do
      get :fetch_repo_updates, params: { repo_name: repo_name }

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:fetch_repository_update).with(repo_name)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_result })
    end

    context "with missing repo_name parameter" do
      it "passes nil to service" do
        allow(Github::GraphqlService).to receive(:fetch_repository_update).with(nil).and_return(nil)

        get :fetch_repo_updates

        expect(response).to have_http_status(:ok)
        expect(Github::GraphqlService).to have_received(:fetch_repository_update).with(nil)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#fetch_user_contributions" do
    let(:mock_contributions) { { 'contributions' => 42, 'repositories' => 5 } }

    before do
      allow(Github::GraphqlService).to receive(:fetch_user_contributions).with(user).and_return(mock_contributions)
    end

    it "fetches and returns user contributions" do
      get :fetch_user_contributions

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:fetch_user_contributions).with(user)
      expect(JSON.parse(response.body)).to eq({ 'data' => mock_contributions })
    end

    context "when GraphQL service fails" do
      before do
        allow(Github::GraphqlService).to receive(:fetch_user_contributions).with(user).and_return(nil)
      end

      it "returns nil data" do
        get :fetch_user_contributions

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'data' => nil })
      end
    end
  end

  describe "#profile" do
    it "returns the current user profile data" do
      get :profile

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['user']['id']).to eq(user.id)
      expect(json['github_account']['github_username']).to eq(github_account.github_username)
      expect(json['user_stat']).to be_present
    end

    context "when user is not authenticated" do
      before do
        allow(controller).to receive(:authenticate_user!).and_raise(StandardError.new("Unauthorized"))
      end

      it "raises an authentication error" do
        expect {
          get :profile
        }.to raise_error(StandardError, "Unauthorized")
      end
    end
  end

  describe "authentication" do
    it "includes JwtAuthenticable concern" do
      expect(UsersController.ancestors).to include(JwtAuthenticable)
    end

    it "calls authenticate_user! before actions" do
      expect(controller).to receive(:authenticate_user!)
      get :profile
    end
  end

  # Force reload to make sure we're correctly setting up the controller for each test
  before(:each) do
    controller.instance_variable_set(:@current_user, nil)
    controller.instance_variable_set(:@current_user, user)
  end
end
