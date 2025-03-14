require 'rails_helper'

RSpec.describe Api::AnalyticsController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_user_stat) }
  let(:repository) { create(:github_repository) }

  before do
    authenticate_user(user)
  end

  describe '#user' do
    before do
      # Create user repository stats
      create(:user_repository_stat,
             user: user,
             github_repository: repository,
             opened_prs_count: 10,
             merged_prs_count: 7,
             closed_prs_count: 2,
             issues_opened_count: 15,
             issues_closed_count: 12,
             contribution_streak: 5,
             first_contribution_at: 6.months.ago,
             last_contribution_at: 1.day.ago
      )

      # Create another repository stat
      create(:user_repository_stat,
             user: user,
             github_repository: create(:github_repository),
             opened_prs_count: 5,
             merged_prs_count: 3,
             contribution_streak: 3
      )
    end

    it 'returns user analytics data' do
      get :user

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('user_id', 'username', 'reputation_points', 'contribution_stats',
                                      'repository_stats', 'time_analytics')

      # Test contribution stats
      expect(json['data']['contribution_stats']).to include('total_prs', 'merged_prs', 'pr_success_rate',
                                                            'total_issues', 'issue_closure_rate')
      expect(json['data']['contribution_stats']['total_prs']).to eq(15) # 10 + 5
      expect(json['data']['contribution_stats']['merged_prs']).to eq(10) # 7 + 3

      # Test repository stats
      expect(json['data']['repository_stats']).to include('active_repositories', 'current_streak')
      expect(json['data']['repository_stats']['active_repositories']).to eq(2)
      expect(json['data']['repository_stats']['current_streak']).to eq(5)

      # Test time analytics
      expect(json['data']['time_analytics']).to include('first_contribution', 'most_recent_contribution')
    end
  end

  describe '#repositories' do
    before do
      # Create repositories with different attributes
      create(:github_repository, language: 'ruby', stars_count: 100, forks_count: 20)
      create(:github_repository, language: 'ruby', stars_count: 50, forks_count: 10)
      create(:github_repository, language: 'javascript', stars_count: 200, forks_count: 30)
      create(:github_repository, language: 'python', stars_count: 150, forks_count: 25)
      create(:github_repository, language: 'go', stars_count: 120, forks_count: 15)

      # Create an inactive repository
      create(:github_repository, github_updated_at: 4.months.ago)
    end

    it 'returns repository analytics data' do
      get :repositories

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('repository_counts', 'average_metrics',
                                      'language_distribution', 'top_repositories')

      # Test repository counts
      expect(json['data']['repository_counts']).to include('total', 'active', 'inactive')

      # Test average metrics
      expect(json['data']['average_metrics']).to include('stars', 'forks')

      # Test language distribution
      expect(json['data']['language_distribution']).to be_a(Hash)
      expect(json['data']['language_distribution'].keys).to include('ruby')

      # Test top repositories
      expect(json['data']['top_repositories']).to be_an(Array)
      expect(json['data']['top_repositories'].size).to be <= 5
    end
  end

  describe '#repository' do
    before do
      # Add PRs
      create_list(:pull_request, 3, github_repository: repository)
      create(:pull_request, github_repository: repository, merged_at: 1.week.ago, closed_at: 1.week.ago)
      create(:pull_request, github_repository: repository, closed_at: 2.weeks.ago)

      # Add Issues
      create_list(:issue, 4, github_repository: repository)
      create_list(:issue, 2, github_repository: repository, closed_at: 2.weeks.ago)

      # Add user repository stats
      create(:user_repository_stat,
             user: user,
             github_repository: repository,
             opened_prs_count: 5,
             merged_prs_count: 4
      )

      other_user = create(:user, :with_github_account)
      create(:user_repository_stat,
             user: other_user,
             github_repository: repository,
             opened_prs_count: 3,
             merged_prs_count: 1
      )
    end

    it 'returns repository analytics data' do
      get :repository, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('repository', 'pull_request_stats',
                                      'issue_stats', 'top_contributors', 'activity_trend')

      # Test repository data
      expect(json['data']['repository']).to include('id', 'full_name', 'stars', 'forks')
      expect(json['data']['repository']['id']).to eq(repository.id)

      # Test PR stats
      expect(json['data']['pull_request_stats']).to include('total', 'open', 'merged', 'closed')
      expect(json['data']['pull_request_stats']['total']).to eq(5)
      expect(json['data']['pull_request_stats']['merged']).to eq(1)

      # Test issue stats
      expect(json['data']['issue_stats']).to include('total', 'open', 'closed')
      expect(json['data']['issue_stats']['total']).to eq(6)
      expect(json['data']['issue_stats']['closed']).to eq(2)

      # Test top contributors
      expect(json['data']['top_contributors']).to be_an(Array)
      expect(json['data']['top_contributors'].size).to be <= 5

      # Test activity trend
      expect(json['data']['activity_trend']).to be_an(Array)
      expect(json['data']['activity_trend'].size).to eq(6) # 6 months
    end

    it 'handles repository not found' do
      get :repository, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  private

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
