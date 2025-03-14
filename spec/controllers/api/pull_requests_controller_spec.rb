require 'rails_helper'

RSpec.describe Api::PullRequestsController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:repository) { create(:github_repository) }
  let(:pull_request) { create(:pull_request, github_repository: repository) }

  describe '#show' do
    before do
      skip_authentication
    end

    it 'returns pull request data with related information' do
      get :show, params: { id: pull_request.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_request']['id']).to eq(pull_request.id)
      expect(json['data']['repository']['id']).to eq(repository.id)
    end

    it 'handles pull request not found' do
      get :show, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Pull request not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#repository_pull_requests' do
    let!(:open_pr) { create(:pull_request, github_repository: repository, closed_at: nil, merged_at: nil) }
    let!(:closed_pr) { create(:pull_request, github_repository: repository, closed_at: 1.day.ago, merged_at: nil) }
    let!(:merged_pr) { create(:pull_request, github_repository: repository, closed_at: 1.day.ago, merged_at: 1.day.ago) }
    let!(:draft_pr) { create(:pull_request, github_repository: repository, is_draft: true) }
    let!(:label) { create(:label, github_repository: repository) }
    let!(:pr_label) { create(:pull_request_label, pull_request: open_pr, label: label) }

    before do
      skip_authentication
    end

    it 'returns repository pull requests with pagination' do
      get :repository_pull_requests, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(4)
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
    end

    it 'filters by open state' do
      get :repository_pull_requests, params: { id: repository.id, state: 'open' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(2)
      expect(json['data']['pull_requests'][0]['id']).to eq(draft_pr.id)
      expect(json['data']['pull_requests'][1]['id']).to eq(open_pr.id)
    end

    it 'filters by closed state' do
      get :repository_pull_requests, params: { id: repository.id, state: 'closed' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(2)
      expect(json['data']['pull_requests'].map { |pr| pr['id'] }).to include(closed_pr.id, merged_pr.id)
    end

    it 'filters by merged state' do
      get :repository_pull_requests, params: { id: repository.id, state: 'merged' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(1)
      expect(json['data']['pull_requests'][0]['id']).to eq(merged_pr.id)
    end

    it 'filters by draft state' do
      get :repository_pull_requests, params: { id: repository.id, state: 'draft' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(1)
      expect(json['data']['pull_requests'][0]['id']).to eq(draft_pr.id)
    end

    it 'filters by labels' do
      get :repository_pull_requests, params: { id: repository.id, labels: label.name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(1)
      expect(json['data']['pull_requests'][0]['id']).to eq(open_pr.id)
    end

    it 'filters by date range' do
      recent_pr = create(:pull_request, github_repository: repository, github_created_at: 1.hour.ago)

      get :repository_pull_requests, params: { id: repository.id, since: 2.hours.ago.iso8601 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(1)
      expect(json['data']['pull_requests'][0]['id']).to eq(recent_pr.id)
    end

    it 'handles repository not found' do
      get :repository_pull_requests, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#user_pull_requests' do
    let!(:user_pr1) { create(:pull_request, author_username: user.github_account.github_username, github_repository: repository) }
    let!(:user_pr2) { create(:pull_request, author_username: user.github_account.github_username, github_repository: repository) }
    let!(:others_pr) { create(:pull_request, author_username: 'someone-else', github_repository: repository) }

    before do
      authenticate_user(user)
    end

    it 'returns user pull requests with pagination' do
      get :user_pull_requests

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(2)
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
    end

    it 'applies state filters correctly' do
      merged_pr = create(:pull_request,
                         author_username: user.github_account.github_username,
                         github_repository: repository,
                         merged_at: 1.day.ago,
                         closed_at: 1.day.ago
      )

      get :user_pull_requests, params: { state: 'merged' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['pull_requests'].length).to eq(1)
      expect(json['data']['pull_requests'][0]['id']).to eq(merged_pr.id)
    end
  end

  private

  def skip_authentication
    allow(controller).to receive(:authenticate_user!).and_return(nil)
  end

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
