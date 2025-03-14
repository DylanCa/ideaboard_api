require 'rails_helper'

RSpec.describe Api::IssuesController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:repository) { create(:github_repository) }
  let(:issue) { create(:issue, github_repository: repository) }

  describe '#show' do
    before do
      skip_authentication
    end

    it 'returns issue data with related information' do
      get :show, params: { id: issue.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issue']['id']).to eq(issue.id)
      expect(json['data']['repository']['id']).to eq(repository.id)
    end

    it 'handles issue not found' do
      get :show, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json).to eq({ "data" => nil, "error" => { "message" => "Issue not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#repository_issues' do
    let!(:issue1) { create(:issue, github_repository: repository, github_created_at: 1.day.ago) }
    let!(:issue2) { create(:issue, github_repository: repository, github_created_at: 2.days.ago) }
    let!(:closed_issue) { create(:issue, github_repository: repository, closed_at: 1.day.ago) }
    let!(:label) { create(:label, github_repository: repository) }
    let!(:issue_label) { create(:issue_label, issue: issue1, label: label) }

    before do
      skip_authentication
    end

    it 'returns repository issues with pagination' do
      get :repository_issues, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(3)
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
    end

    it 'filters by state' do
      get :repository_issues, params: { id: repository.id, state: 'closed' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(1)
      expect(json['data']['issues'][0]['id']).to eq(closed_issue.id)
    end

    it 'filters by labels' do
      get :repository_issues, params: { id: repository.id, labels: label.name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(1)
      expect(json['data']['issues'][0]['id']).to eq(issue1.id)
    end

    it 'filters by date range' do
      get :repository_issues, params: { id: repository.id, since: 1.5.days.ago.iso8601 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(1)
      expect(json['data']['issues'][0]['id']).to eq(issue1.id)
    end

    it 'handles repository not found' do
      get :repository_issues, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#user_issues' do
    let!(:user_issue1) { create(:issue, author_username: user.github_account.github_username, github_repository: repository) }
    let!(:user_issue2) { create(:issue, author_username: user.github_account.github_username, github_repository: repository) }
    let!(:others_issue) { create(:issue, author_username: 'someone-else', github_repository: repository) }

    before do
      authenticate_user(user)
    end

    it 'returns user issues with pagination' do
      get :user_issues

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(2)
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
    end

    it 'applies filters correctly' do
      # Add a closed issue for the user
      closed_issue = create(:issue,
                            author_username: user.github_account.github_username,
                            github_repository: repository,
                            closed_at: 1.day.ago
      )

      get :user_issues, params: { state: 'closed' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['issues'].length).to eq(1)
      expect(json['data']['issues'][0]['id']).to eq(closed_issue.id)
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
