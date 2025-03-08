require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }
  let(:github_account) { user.github_account }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(JwtAuthenticable).to receive(:extract_token).and_return("test-token")
    allow(JwtService).to receive(:decode).and_return({ "user_id" => user.id, "github_username" => user.github_account.github_username })
    allow(User).to receive(:joins).and_return(User)
    allow(User).to receive(:find_by!).and_return(user)
    controller.send(:authenticate_user!)
  end

  before(:each) do
    controller.instance_variable_set(:@current_user, nil)
    controller.instance_variable_set(:@current_user, user)
  end

  describe "#current_user" do
    before do
      mock_github_query('user_data')
      allow(Github::GraphqlService).to receive(:fetch_current_user_data).with(user).and_call_original
    end

    it "fetches and returns the current user data" do
      get :current_user

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).not_to be_nil
    end
  end

  describe "#user_repos" do
    before do
      mock_response = mock_github_query('user_repositories')
      allow(Github::GraphqlService).to receive(:fetch_current_user_repositories).with(user).and_return(mock_response.data.viewer.repositories.nodes)
    end

    it "fetches and returns the user's repositories" do
      get :user_repos

      expect(response).to have_http_status(:ok)
      expect(Github::GraphqlService).to have_received(:fetch_current_user_repositories)

      result = JSON.parse(response.body)
      expect(result['data']).to be_an(Array)
      expect(result['data'].size).to eq(2) # Based on fixture
    end
  end

  describe "#update_repositories_data" do
    before do
      mock_response = mock_github_query('repository_data')
      repo_result = {
        'updated' => true,
        'repository' => mock_response.data.repository.name_with_owner,
        'stars' => mock_response.data.repository.stargazer_count
      }
      allow(Github::GraphqlService).to receive(:update_repositories_data).and_return(repo_result)
    end

    it "updates and returns repository data" do
      get :update_repositories_data

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include('updated' => true)
    end
  end

  describe "#add_repository" do
    let(:repo_name) { 'owner/repo' }

    before do
      mock_response = mock_github_query('repository_data')
      repo_result = {
        'added' => true,
        'repository' => mock_response.data.repository.name_with_owner
      }
      allow(Github::GraphqlService).to receive(:add_repo_by_name).with(repo_name).and_return(repo_result)
    end

    it "adds and returns repository data" do
      get :add_repository, params: { repo_name: repo_name }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include('added' => true)
    end
  end

  describe "#fetch_repo_updates" do
    let(:repo_name) { 'owner/repo' }

    before do
      mock_prs = mock_github_query('repository_prs')
      mock_issues = mock_github_query('repository_issues')

      update_result = {
        'updated' => true,
        'repository' => repo_name,
        'prs_count' => mock_prs.data.repository.pull_requests.nodes.size,
        'issues_count' => mock_issues.data.repository.issues.nodes.size
      }

      allow(Github::GraphqlService).to receive(:fetch_repository_update).with(repo_name).and_return(update_result)
    end

    it "fetches and returns repository updates" do
      get :fetch_repo_updates, params: { repo_name: repo_name }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include('updated' => true)
    end
  end

  describe "#fetch_user_contributions" do
    before do
      mock_prs = mock_github_query('search_query_prs')
      mock_issues = mock_github_query('search_query_issues')

      contributions = {
        'contributions' => mock_prs.data.search.nodes.size + mock_issues.data.search.nodes.size,
        'prs_count' => mock_prs.data.search.nodes.size,
        'issues_count' => mock_issues.data.search.nodes.size
      }

      allow(Github::GraphqlService).to receive(:fetch_user_contributions).with(user).and_return(contributions)
    end

    it "fetches and returns user contributions" do
      get :fetch_user_contributions

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include('contributions', 'prs_count', 'issues_count')
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
end
