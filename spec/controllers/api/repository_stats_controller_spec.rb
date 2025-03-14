require 'rails_helper'

RSpec.describe Api::RepositoryStatsController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:repository) { create(:github_repository) }

  before do
    authenticate_user(user)
  end

  describe '#index' do
    let!(:user_repo_stat1) { create(:user_repository_stat,
                                    user: user,
                                    github_repository: repository,
                                    last_contribution_at: 1.day.ago,
                                    opened_prs_count: 5,
                                    merged_prs_count: 3,
                                    issues_opened_count: 2
    )}

    let!(:user_repo_stat2) { create(:user_repository_stat,
                                    user: user,
                                    github_repository: create(:github_repository),
                                    last_contribution_at: 2.days.ago,
                                    opened_prs_count: 3,
                                    merged_prs_count: 2,
                                    issues_opened_count: 1
    )}

    it 'returns repository stats for the current user with pagination' do
      get :index

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repository_stats'].length).to eq(2)
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')

      # Stats should be ordered by last_contribution_at desc
      expect(json['data']['repository_stats'][0]['id']).to eq(user_repo_stat1.id)
      expect(json['data']['repository_stats'][1]['id']).to eq(user_repo_stat2.id)

      # Check structure of the stats
      first_stat = json['data']['repository_stats'][0]
      expect(first_stat).to include('id', 'repository', 'stats')
      expect(first_stat['repository']).to include('id', 'full_name', 'description')
      expect(first_stat['stats']).to include(
                                       'opened_prs_count', 'merged_prs_count', 'issues_opened_count',
                                       'issues_closed_count', 'contribution_streak'
                                     )
    end

    it 'respects pagination parameters' do
      get :index, params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repository_stats'].length).to eq(1)
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_pages']).to eq(2)
    end
  end

  describe '#show' do
    context 'when stats exist for repository' do
      let!(:user_repo_stat) { create(:user_repository_stat,
                                     user: user,
                                     github_repository: repository,
                                     opened_prs_count: 5,
                                     merged_prs_count: 3,
                                     issues_opened_count: 2
      )}

      it 'returns the repository stats for the specific repository' do
        get :show, params: { id: repository.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['repository_stats']).to include('id', 'repository', 'stats')
        expect(json['data']['repository_stats']['id']).to eq(user_repo_stat.id)
        expect(json['data']['repository_stats']['repository']['id']).to eq(repository.id)
        expect(json['data']['repository_stats']['stats']).to include(
                                                               'opened_prs_count', 'merged_prs_count', 'issues_opened_count'
                                                             )
        expect(json['data']['repository_stats']['stats']['opened_prs_count']).to eq(5)
      end
    end

    context 'when no stats exist for repository' do
      it 'returns not found error' do
        get :show, params: { id: repository.id }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']['message']).to eq('No contribution statistics found for this repository')
      end
    end

    context 'when repository does not exist' do
      it 'returns not found error' do
        allow(GithubRepository).to receive(:find).and_raise(ActiveRecord::RecordNotFound)

        get :show, params: { id: 999999 }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']['message']).to eq('No contribution statistics found for this repository')
      end
    end
  end

  private

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
