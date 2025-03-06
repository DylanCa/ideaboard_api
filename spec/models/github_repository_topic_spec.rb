require 'rails_helper'

RSpec.describe GithubRepositoryTopic, type: :model do
  subject { create(:github_repository_topic) }

  describe 'associations' do
    it { should belong_to(:github_repository) }
    it { should belong_to(:topic) }
  end

  describe 'validations' do
    it { should validate_presence_of(:github_repository_id) }
    it { should validate_presence_of(:topic_id) }
    it { should validate_uniqueness_of(:github_repository_id).scoped_to(:topic_id) }
  end

  describe 'creation' do
    let(:github_repository) { create(:github_repository) }
    let(:topic) { create(:topic) }

    it 'creates a valid repository-topic association' do
      repo_topic = GithubRepositoryTopic.new(
        github_repository: github_repository,
        topic: topic
      )
      expect(repo_topic).to be_valid
    end
  end
end
