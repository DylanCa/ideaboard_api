require 'rails_helper'

RSpec.describe Api::RepositoriesController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:repository) { create(:github_repository, visible: true) }

  describe '#index' do
    before do
      skip_authentication
      create_list(:github_repository, 5, visible: true)
      create(:github_repository, visible: false) # Should be excluded

      # Create repositories with specific language for filtering
      create(:github_repository, visible: true, language: 'ruby')
      create(:github_repository, visible: true, language: 'ruby')

      # Create repository with specific topic for filtering
      @topic_repo = create(:github_repository, visible: true)
      topic = create(:topic, name: 'test-topic')
      create(:github_repository_topic, github_repository: @topic_repo, topic: topic)
    end

    it 'returns visible repositories with pagination' do
      get :index

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories'].length).to be <= 20
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')
      expect(json['meta']['total_count']).to eq(8) # Total visible repos
    end

    it 'filters by language' do
      existing_count = GithubRepository.where(visible: true, language: 'ruby').count

      create_list(:github_repository, 3, visible: true, language: 'ruby')
      create_list(:github_repository, 2, visible: true, language: 'javascript')

      get :index, params: { language: 'ruby' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories'].length).to eq(existing_count + 3)
      json['data']['repositories'].each do |repo|
        expect(repo['language']).to eq('ruby')
      end
    end

    it 'filters by topic' do
      get :index, params: { topic: 'test-topic' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories'].length).to eq(1)
      expect(json['data']['repositories'][0]['id']).to eq(@topic_repo.id)
    end

    it 'respects pagination parameters' do
      get :index, params: { page: 2, per_page: 3 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories'].length).to be <= 3
      expect(json['meta']['current_page']).to eq(2)
    end
  end

  describe '#show' do
    let!(:topics) { create_list(:topic, 2) }
    let!(:labels) { create_list(:label, 2, github_repository: repository) }

    before do
      skip_authentication
      topics.each do |topic|
        create(:github_repository_topic, github_repository: repository, topic: topic)
      end
    end

    it 'returns repository with topics and labels' do
      get :show, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repository']['id']).to eq(repository.id)
      expect(json['data']['topics'].length).to eq(2)
      expect(json['data']['labels'].length).to eq(2)
    end

    it 'works with repository full name' do
      get :show, params: { id: repository.full_name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repository']['id']).to eq(repository.id)
    end
  end

  describe '#create' do
    before do
      authenticate_user(user)
      allow(RepositoryDataFetcherWorker).to receive(:perform_async)
    end

    it 'starts repository fetch job' do
      repo_name = 'owner/new-repo'

      post :create, params: { repository_full_name: repo_name }

      expect(response).to have_http_status(:accepted)
      expect(RepositoryDataFetcherWorker).to have_received(:perform_async).with(repo_name)

      json = JSON.parse(response.body)
      expect(json['data']['message']).to include('Repository add job started')
      expect(json['data']['repository_name']).to eq(repo_name)
    end

    it 'returns existing repository if already exists' do
      post :create, params: { repository_full_name: repository.full_name }

      expect(response).to have_http_status(:ok)
      expect(RepositoryDataFetcherWorker).not_to have_received(:perform_async)

      json = JSON.parse(response.body)
      expect(json['data']['message']).to include('Repository already exists')
      expect(json['data']['repository']['id']).to eq(repository.id)
    end
  end

  describe '#trending' do
    before do
      skip_authentication

      # Create repositories with recent activity
      @trending_repo = create(:github_repository, visible: true, github_updated_at: 1.day.ago)
      create(:pull_request, github_repository: @trending_repo, github_created_at: 1.day.ago)
      create(:issue, github_repository: @trending_repo, github_created_at: 1.day.ago)

      # Create older repository with less activity
      @old_repo = create(:github_repository, visible: true, github_updated_at: 2.months.ago)
    end

    it 'returns trending repositories' do
      get :trending

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty

      # The trending repo should be first in the results
      if json['data']['repositories'].length > 1
        expect(json['data']['repositories'].first['id']).to eq(@trending_repo.id)
      end
    end
  end

  describe '#featured' do
    before do
      skip_authentication

      # Create featured repository
      @featured_repo = create(:github_repository,
                              visible: true,
                              has_contributing: true,
                              stars_count: 150
      )

      # Create non-featured repository
      @normal_repo = create(:github_repository,
                            visible: true,
                            has_contributing: false,
                            stars_count: 50
      )
    end

    it 'returns featured repositories' do
      get :featured

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty

      # Should only include the featured repo
      repo_ids = json['data']['repositories'].map { |r| r['id'] }
      expect(repo_ids).to include(@featured_repo.id)
      expect(repo_ids).not_to include(@normal_repo.id)
    end
  end

  describe '#qualification' do
    before do
      skip_authentication
    end

    it 'returns qualification metrics for repository' do
      # Update repository with qualification data
      repository.update(
        license: 'mit',
        has_contributing: true,
        github_updated_at: 1.week.ago,
        archived: false,
        disabled: false
      )

      # Add open issues
      create(:issue, github_repository: repository, closed_at: nil)

      get :qualification, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['qualification']).to include(
                                                 'has_license', 'has_contributing', 'is_active',
                                                 'has_open_issues', 'is_not_archived', 'is_not_disabled',
                                                 'qualifies'
                                               )

      # Should qualify since all conditions are met
      expect(json['data']['qualification']['qualifies']).to be true
    end

    it 'marks repository as not qualifying when conditions are not met' do
      # Update repository without some qualification requirements
      repository.update(
        license: nil,
        has_contributing: false,
        github_updated_at: 4.months.ago
      )

      get :qualification, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['qualification']['qualifies']).to be false
    end
  end

  describe '#visibility' do
    before do
      authenticate_user(user)
      repository.update(author_username: user.github_account.github_username)
    end

    it 'updates repository visibility when user is owner' do
      original_visibility = repository.visible

      put :visibility, params: { id: repository.id, visible: !original_visibility }

      expect(response).to have_http_status(:ok)
      repository.reload
      expect(repository.visible).to eq(!original_visibility)
    end

    it 'rejects visibility update when user is not repository owner' do
      other_repo = create(:github_repository, author_username: 'someone-else')

      put :visibility, params: { id: other_repo.id, visible: !other_repo.visible }

      expect(response).to have_http_status(:unauthorized)
      other_repo.reload
      expect(other_repo.visible).not_to eq(!other_repo.visible)
    end
  end

  describe '#update_data' do
    before do
      authenticate_user(user)
      allow(RepositoryUpdateWorker).to receive(:perform_async)
    end

    it 'starts repository update job' do
      post :update_data, params: { id: repository.id }

      expect(response).to have_http_status(:accepted)
      expect(RepositoryUpdateWorker).to have_received(:perform_async).with(repository.full_name)

      json = JSON.parse(response.body)
      expect(json['data']['message']).to include('Repository update job started')
    end
  end

  describe '#refresh' do
    before do
      authenticate_user(user)
      allow(Github::GraphqlService).to receive(:update_repositories_data)
    end

    it 'starts refresh job for all repositories' do
      post :refresh

      expect(response).to have_http_status(:accepted)
      expect(Github::GraphqlService).to have_received(:update_repositories_data)

      json = JSON.parse(response.body)
      expect(json['data']['message']).to include('Repository refresh job started')
    end

    it 'requires authentication' do
      skip_authentication

      post :refresh

      expect(response).to have_http_status(:unauthorized)
      expect(Github::GraphqlService).not_to have_received(:update_repositories_data)
    end
  end

  describe '#search' do
    before do
      skip_authentication

      # Create repositories for search results
      @ruby_repo = create(:github_repository,
                          visible: true,
                          full_name: 'owner/ruby-project',
                          description: 'A Ruby project',
                          language: 'ruby',
                          stars_count: 100
      )

      @js_repo = create(:github_repository,
                        visible: true,
                        full_name: 'owner/js-project',
                        description: 'A JavaScript project',
                        language: 'javascript',
                        stars_count: 50
      )

      # Add topic to ruby repo
      ruby_topic = create(:topic, name: 'ruby')
      create(:github_repository_topic, github_repository: @ruby_repo, topic: ruby_topic)
    end

    it 'searches repositories by query' do
      get :search, params: { q: 'ruby' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty
      expect(json['data']['repositories'].map { |r| r['id'] }).to include(@ruby_repo.id)
    end

    it 'filters search by language' do
      get :search, params: { language: 'javascript' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty
      expect(json['data']['repositories'].map { |r| r['id'] }).to include(@js_repo.id)
      expect(json['data']['repositories'].map { |r| r['id'] }).not_to include(@ruby_repo.id)
    end

    it 'filters search by topic' do
      get :search, params: { topic: 'ruby' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty
      expect(json['data']['repositories'].map { |r| r['id'] }).to include(@ruby_repo.id)
      expect(json['data']['repositories'].map { |r| r['id'] }).not_to include(@js_repo.id)
    end

    it 'sorts search results correctly' do
      # Test stars sorting (default)
      get :search, params: { sort: 'stars' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      if json['data']['repositories'].length >= 2
        expect(json['data']['repositories'][0]['id']).to eq(@ruby_repo.id) # Higher stars count
      end

      # Test other sorting options
      %w[forks recent created].each do |sort_option|
        get :search, params: { sort: sort_option }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#recommendations' do
    before do
      # Create repositories and user stats for recommendations
      @ruby_repo = create(:github_repository, language: 'ruby')
      @js_repo = create(:github_repository, language: 'javascript')

      # Add topics
      ruby_topic = create(:topic, name: 'ruby')
      js_topic = create(:topic, name: 'javascript')

      create(:github_repository_topic, github_repository: @ruby_repo, topic: ruby_topic)
      create(:github_repository_topic, github_repository: @js_repo, topic: js_topic)

      # Create user stat for contributed repository
      @contributed_repo = create(:github_repository, language: 'ruby')
      create(:user_repository_stat, user: user, github_repository: @contributed_repo)

      # Add same topic to contributed repo
      create(:github_repository_topic, github_repository: @contributed_repo, topic: ruby_topic)
    end

    it 'returns personalized recommendations when authenticated' do
      authenticate_user(user)

      get :recommendations

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty
      # Should recommend ruby repo but not the one user already contributed to
      repo_ids = json['data']['repositories'].map { |r| r['id'] }
      expect(repo_ids).to include(@ruby_repo.id)
      expect(repo_ids).not_to include(@contributed_repo.id)
    end

    it 'requires authentication' do
      skip_authentication

      get :recommendations

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '#needs_help' do
    before do
      skip_authentication

      # Create repository needing help (many open issues, old update)
      @needs_help_repo = create(:github_repository,
                                visible: true,
                                github_updated_at: 2.months.ago
      )
      create_list(:issue, 5, github_repository: @needs_help_repo, closed_at: nil)

      # Create repository not needing help
      @healthy_repo = create(:github_repository,
                             visible: true,
                             github_updated_at: 1.day.ago
      )
      create(:issue, github_repository: @healthy_repo, closed_at: 1.day.ago)
    end

    it 'returns repositories needing help' do
      get :needs_help

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories']).not_to be_empty
      repo_ids = json['data']['repositories'].map { |r| r['id'] }
      expect(repo_ids).to include(@needs_help_repo.id)
      # May or may not include healthy repo depending on implementation
    end
  end

  describe '#health' do
    before do
      skip_authentication

      # Set up repository with health metrics
      repository.update(
        license: 'mit',
        has_contributing: true,
        github_updated_at: 1.week.ago,
        stars_count: 100,
        forks_count: 20
      )

      # Add PRs and issues
      create_list(:pull_request, 3, github_repository: repository, merged_at: 1.week.ago)
      create_list(:issue, 5, github_repository: repository)
      create_list(:issue, 2, github_repository: repository, closed_at: 2.weeks.ago)
    end

    it 'returns repository health metrics' do
      get :health, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['health']).to include(
                                          'stars_count', 'forks_count', 'has_license', 'has_contributing',
                                          'is_active', 'is_not_archived', 'is_not_disabled', 'health_score'
                                        )
    end

    it 'handles repository not found' do
      get :health, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#activity' do
    before do
      skip_authentication

      # Create PRs and issues for activity
      create_list(:pull_request, 2, github_repository: repository, github_created_at: 1.week.ago)
      create_list(:issue, 3, github_repository: repository, github_created_at: 2.weeks.ago)
    end

    it 'returns repository activity data' do
      get :activity, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('repository_id', 'repository_name', 'activities')
      expect(json['data']['activities']).not_to be_empty
      expect(json['data']['activities'].map { |a| a['type'] }).to include('pull_request', 'issue')
    end

    it 'handles repository not found' do
      get :activity, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#topics' do
    before do
      skip_authentication

      # Create topics and associate with repository
      @topics = create_list(:topic, 3)
      @topics.each do |topic|
        create(:github_repository_topic, github_repository: repository, topic: topic)
      end
    end

    it 'returns repository topics' do
      get :topics, params: { id: repository.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to include('repository', 'topics')
      expect(json['data']['topics'].length).to eq(3)
    end

    it 'works with repository full name' do
      get :topics, params: { id: repository.full_name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repository']['full_name']).to eq(repository.full_name)
      expect(json['data']['topics'].length).to eq(3)
    end

    it 'handles repository not found' do
      get :topics, params: { id: 'nonexistent/repo' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Repository not found", "status" => 404 }, "meta" => {} })
    end
  end

  private

  def skip_authentication
    allow(controller).to receive(:authenticate_user!).and_return(nil)
    controller.instance_variable_set(:@current_user, nil)
  end

  def authenticate_user(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end
end
