require 'rails_helper'

RSpec.describe Topic, type: :model do
  subject { create(:topic) }

  describe 'associations' do
    it { should have_many(:github_repository_topics).dependent(:destroy) }
    it { should have_many(:github_repositories).through(:github_repository_topics) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end
end
