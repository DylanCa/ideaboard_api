require 'rails_helper'

RSpec.describe Issue, type: :model do
  describe 'associations' do
    it { should belong_to(:github_repository) }
    it { should have_many(:issue_labels).dependent(:destroy) }
    it { should have_many(:labels).through(:issue_labels) }
  end

  describe 'validations' do
    it { should validate_presence_of(:author_username) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:number) }
    it { should validate_presence_of(:github_created_at) }
    it { should validate_presence_of(:github_updated_at) }

    it { should validate_uniqueness_of(:github_id).allow_nil }

    describe 'number uniqueness within repository' do
      subject { create(:issue) }
      it { should validate_uniqueness_of(:number).scoped_to(:github_repository_id) }
    end
  end

  describe 'scopes' do
    let!(:open_issue) { create(:issue, closed_at: nil) }
    let!(:closed_issue) { create(:issue, closed_at: Time.current) }
    let!(:user_issue) { create(:issue, author_username: 'test-user') }
    let!(:other_user_issue) { create(:issue, author_username: 'other-user') }
    let!(:old_issue) { create(:issue, github_created_at: 1.year.ago) }
    let!(:new_issue) { create(:issue, github_created_at: 1.day.ago) }

    describe '.open' do
      it 'returns issues that are not closed' do
        expect(Issue.open).to include(open_issue)
        expect(Issue.open).not_to include(closed_issue)
      end
    end

    describe '.closed' do
      it 'returns issues that are closed' do
        expect(Issue.closed).to include(closed_issue)
        expect(Issue.closed).not_to include(open_issue)
      end
    end

    describe '.by_author' do
      it 'returns issues by the specified author' do
        expect(Issue.by_author('test-user')).to include(user_issue)
        expect(Issue.by_author('test-user')).not_to include(other_user_issue)
      end
    end

    describe '.recent' do
      it 'returns issues ordered by creation date in descending order' do
        expect(Issue.recent.first).to eq(new_issue)
        expect(Issue.recent.last).to eq(old_issue)
      end
    end
  end

  describe '#state' do
    context 'when issue is open' do
      let(:issue) { create(:issue, closed_at: nil) }

      it 'returns the open state' do
        expect(issue.state).to eq(Issue::STATE[:open])
      end
    end

    context 'when issue is closed' do
      let(:issue) { create(:issue, closed_at: Time.current) }

      it 'returns the closed state' do
        expect(issue.state).to eq(Issue::STATE[:closed])
      end
    end
  end

  describe 'STATE constant' do
    it 'defines correct state values' do
      expect(Issue::STATE[:draft]).to eq(0)
      expect(Issue::STATE[:open]).to eq(1)
      expect(Issue::STATE[:closed]).to eq(2)
      expect(Issue::STATE[:merged]).to eq(3)
    end
  end
end
