require 'rails_helper'

RSpec.describe Api::TopicsController, type: :controller do
  let(:user) { create(:user, :with_github_account) }
  let(:topic) { create(:topic, name: 'ruby') }

  before do
    skip_authentication
  end

  describe '#index' do
    before do
      # Create several topics
      create_list(:topic, 5)
    end

    it 'returns all topics without pagination' do
      get :index

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topics']).to be_an(Array)
      expect(json['data']['topics'].length).to eq(Topic.count)
    end

    it 'respects pagination parameters' do
      create_list(:topic, 10) # Create more topics to test pagination

      get :index, params: { page: 2, per_page: 5 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topics'].length).to eq(5)
      expect(json['meta']['current_page']).to eq(2)
    end
  end

  describe '#show' do
    it 'returns topic by id' do
      get :show, params: { id: topic.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topic']['id']).to eq(topic.id)
      expect(json['data']['topic']['name']).to eq('ruby')
    end

    it 'returns topic by name' do
      get :show, params: { id: topic.name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topic']['id']).to eq(topic.id)
      expect(json['data']['topic']['name']).to eq('ruby')
    end

    it 'handles topic not found' do
      get :show, params: { id: 'nonexistent' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Topic not found", "status" => 404 }, "meta" => {} })
    end
  end

  describe '#repositories' do
    let!(:repo1) { create(:github_repository, visible: true) }
    let!(:repo2) { create(:github_repository, visible: true) }
    let!(:repo3) { create(:github_repository, visible: false) } # Should be excluded

    before do
      # Associate repositories with the topic
      create(:github_repository_topic, github_repository: repo1, topic: topic)
      create(:github_repository_topic, github_repository: repo2, topic: topic)
      create(:github_repository_topic, github_repository: repo3, topic: topic)
    end

    it 'returns repositories for a topic with pagination' do
      get :repositories, params: { id: topic.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topic']['id']).to eq(topic.id)
      expect(json['data']['repositories'].length).to eq(2) # Only visible repos
      expect(json['meta']).to include('total_count', 'current_page', 'total_pages')

      repo_ids = json['data']['repositories'].map { |r| r['id'] }
      expect(repo_ids).to include(repo1.id, repo2.id)
      expect(repo_ids).not_to include(repo3.id)
    end

    it 'works with topic name' do
      get :repositories, params: { id: topic.name }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['topic']['name']).to eq(topic.name)
    end

    it 'handles topic not found' do
      get :repositories, params: { id: 'nonexistent' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to eq({ "data" => nil, "error" => { "message" => "Topic not found", "status" => 404 }, "meta" => {} })
    end

    it 'respects pagination parameters' do
      # Create more repositories with the same topic
      additional_repos = create_list(:github_repository, 5, visible: true)
      additional_repos.each do |repo|
        create(:github_repository_topic, github_repository: repo, topic: topic)
      end

      get :repositories, params: { id: topic.id, page: 1, per_page: 3 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['repositories'].length).to eq(3)
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_pages']).to eq(3) # 7 visible repos / 3 per page = 3 pages
    end
  end

  private

  def skip_authentication
    allow(controller).to receive(:authenticate_user!).and_return(nil)
    controller.instance_variable_set(:@current_user, nil)
  end
end
