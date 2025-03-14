require 'rails_helper'

RSpec.describe Api::ContributionsController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }
  let(:repository) { create(:github_repository) }
  let(:other_repository) { create(:github_repository) }

  before do
    # Set up authentication for controllers that require it
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end

  describe '#user_contributions' do
    let!(:user_repo_stat1) { create(:user_repository_stat, user: user, github_repository: repository) }
    let!(:user_repo_stat2) { create(:user_repository_stat, user: user, github_repository: other_repository) }

    it 'returns user contributions with totals and pagination' do
      get :user_contributions

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['contributions'].length).to eq(2)
      expect(json['data']['totals']).to include(
                                          'total_prs', 'total_merged_prs', 'total_issues',
                                          'total_closed_issues', 'total_repositories'
                                        )
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
    end

    it 'respects pagination parameters' do
      get :user_contributions, params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['contributions'].length).to eq(1)
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_pages']).to eq(2)
    end
  end

  describe '#user_history' do
    let!(:pull_request1) { create(:pull_request, author_username: user.github_account.github_username,
                                  github_created_at: 1.month.ago, github_repository: repository) }
    let!(:pull_request2) { create(:pull_request, author_username: user.github_account.github_username,
                                  github_created_at: 2.months.ago, github_repository: repository,
                                  merged_at: 2.months.ago) }
    let!(:issue1) { create(:issue, author_username: user.github_account.github_username,
                           github_created_at: 1.month.ago, github_repository: repository) }

    it 'returns monthly contributions history' do
      get :user_history

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['history']).to be_an(Array)
      expect(json['meta']).to include('start_date', 'end_date', 'total_prs', 'total_issues')
    end

    it 'respects date range parameters' do
      get :user_history, params: {
        start_date: 3.months.ago.to_date.to_s,
        end_date: 1.day.ago.to_date.to_s
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(Date.parse(json['meta']['start_date'])).to eq(3.months.ago.to_date)
      expect(Date.parse(json['meta']['end_date'])).to eq(1.day.ago.to_date)
    end
  end

  describe '#user_streaks' do
    before do
      # Set up user repository stats with contribution streak
      create(:user_repository_stat, user: user, contribution_streak: 5, github_repository: repository)
      create(:user_repository_stat, user: user, contribution_streak: 3, github_repository: other_repository)

      # Create some PRs and issues for calendar data
      create(:pull_request, author_username: user.github_account.github_username,
             github_created_at: 1.day.ago, github_repository: repository)
      create(:issue, author_username: user.github_account.github_username,
             github_created_at: 2.days.ago, github_repository: repository)
    end

    it 'returns streak information and calendar data' do
      get :user_streaks

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['current_streak']).to eq(5)
      expect(json['data']['longest_streak']).to eq(5)
      expect(json['data']['calendar_data']).to be_an(Array)
    end
  end

  describe '#repository_contributions' do
    let!(:user_repo_stat) { create(:user_repository_stat, user: user, github_repository: repository) }
    let!(:other_user) { create(:user, :with_github_account) }
    let!(:other_user_repo_stat) { create(:user_repository_stat, user: other_user, github_repository: repository) }

    before do
      # Ensure controller doesn't require authentication for this action
      allow(controller).to receive(:authenticate_user!).and_return(nil)
      controller.instance_variable_set(:@current_user, nil)
    end

    it 'returns repository contributions with totals and pagination' do
      get :repository_contributions, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['contributions'].length).to eq(2)
      expect(json['data']['totals']).to include(
                                          'total_contributors', 'total_prs', 'total_merged_prs', 'total_issues'
                                        )
      expect(json['meta']).to include(
                                'repository', 'stars', 'forks', 'total_count', 'current_page', 'total_pages'
                              )
    end

    it 'handles repository not found' do
      get :repository_contributions, params: { id: 'nonexistent' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)

      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end

    it 'respects pagination parameters' do
      get :repository_contributions, params: { id: repository.id, page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['contributions'].length).to eq(1)
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_pages']).to eq(2)
    end
  end
end
