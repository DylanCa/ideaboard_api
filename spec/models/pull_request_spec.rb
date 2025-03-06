require 'rails_helper'

RSpec.describe PullRequest, type: :model do
  describe 'associations' do
    it { should belong_to(:github_repository) }
    it { should have_many(:pull_request_labels).dependent(:destroy) }
    it { should have_many(:labels).through(:pull_request_labels) }
  end

  describe 'validations' do
    it { should validate_presence_of(:author_username) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:number) }
    it { should validate_presence_of(:github_created_at) }
    it { should validate_presence_of(:github_updated_at) }

    it { should validate_uniqueness_of(:github_id).allow_nil }
    it { should validate_inclusion_of(:is_draft).in_array([ true, false ]) }

    describe 'number uniqueness within repository' do
      subject { create(:pull_request) }
      it { should validate_uniqueness_of(:number).scoped_to(:github_repository_id) }
    end
  end

  describe 'scopes' do
    let!(:open_pr) { create(:pull_request, closed_at: nil, merged_at: nil) }
    let!(:closed_pr) { create(:pull_request, closed_at: Time.current, merged_at: nil) }
    let!(:merged_pr) { create(:pull_request, merged_at: Time.current) }
    let!(:draft_pr) { create(:pull_request, is_draft: true) }
    let!(:user_pr) { create(:pull_request, author_username: 'test-user') }
    let!(:other_user_pr) { create(:pull_request, author_username: 'other-user') }
    let!(:old_pr) { create(:pull_request, github_created_at: 1.year.ago) }
    let!(:new_pr) { create(:pull_request, github_created_at: 1.day.ago) }

    describe '.open' do
      it 'returns PRs that are not closed or merged' do
        expect(PullRequest.open).to include(open_pr)
        expect(PullRequest.open).not_to include(closed_pr)
        expect(PullRequest.open).not_to include(merged_pr)
      end
    end

    describe '.closed' do
      it 'returns PRs that are closed' do
        expect(PullRequest.closed).to include(closed_pr)
        expect(PullRequest.closed).to include(merged_pr) # Merged PRs are also closed
        expect(PullRequest.closed).not_to include(open_pr)
      end
    end

    describe '.merged' do
      it 'returns PRs that are merged' do
        expect(PullRequest.merged).to include(merged_pr)
        expect(PullRequest.merged).not_to include(closed_pr)
        expect(PullRequest.merged).not_to include(open_pr)
      end
    end

    describe '.not_merged' do
      it 'returns PRs that are not merged' do
        expect(PullRequest.not_merged).to include(open_pr)
        expect(PullRequest.not_merged).to include(closed_pr)
        expect(PullRequest.not_merged).not_to include(merged_pr)
      end
    end

    describe '.by_author' do
      it 'returns PRs by the specified author' do
        expect(PullRequest.by_author('test-user')).to include(user_pr)
        expect(PullRequest.by_author('test-user')).not_to include(other_user_pr)
      end
    end

    describe '.not_draft' do
      it 'returns PRs that are not drafts' do
        expect(PullRequest.not_draft).to include(open_pr)
        expect(PullRequest.not_draft).not_to include(draft_pr)
      end
    end

    describe '.recent' do
      it 'returns PRs ordered by creation date in descending order' do
        expect(PullRequest.recent.first).to eq(new_pr)
        expect(PullRequest.recent.last).to eq(old_pr)
      end
    end
  end

  describe '#state' do
    context 'when PR is merged' do
      let(:pr) { create(:pull_request, merged_at: Time.current) }

      it 'returns the merged state' do
        expect(pr.state).to eq(PullRequest::STATE[:merged])
      end
    end

    context 'when PR is closed but not merged' do
      let(:pr) { create(:pull_request, closed_at: Time.current, merged_at: nil) }

      it 'returns the closed state' do
        expect(pr.state).to eq(PullRequest::STATE[:closed])
      end
    end

    context 'when PR is a draft' do
      let(:pr) { create(:pull_request, is_draft: true, closed_at: nil, merged_at: nil) }

      it 'returns the draft state' do
        expect(pr.state).to eq(PullRequest::STATE[:draft])
      end
    end

    context 'when PR is open (not draft, closed, or merged)' do
      let(:pr) { create(:pull_request, is_draft: false, closed_at: nil, merged_at: nil) }

      it 'returns the open state' do
        expect(pr.state).to eq(PullRequest::STATE[:open])
      end
    end
  end

  describe 'STATE constant' do
    it 'defines correct state values' do
      expect(PullRequest::STATE[:draft]).to eq(0)
      expect(PullRequest::STATE[:open]).to eq(1)
      expect(PullRequest::STATE[:closed]).to eq(2)
      expect(PullRequest::STATE[:merged]).to eq(3)
    end
  end
end
