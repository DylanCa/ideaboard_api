require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_one(:github_account).dependent(:destroy) }
    it { should have_one(:user_stat).dependent(:destroy) }
    it { should have_one(:user_token).dependent(:destroy) }
    it { should have_many(:owned_repositories).class_name('GithubRepository').with_foreign_key('owner_id').dependent(:nullify) }
    it { should have_many(:user_repository_stats).dependent(:destroy) }
    it { should have_many(:rate_limit_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:account_status) }
  end

  describe 'enums' do
    it { should define_enum_for(:account_status).with_values(enabled: 1, disabled: 0, banned: -1) }
    it { should define_enum_for(:token_usage_level).with_values(personal: 0, contributed: 1, global_pool: 2).with_default(:personal) }
  end

  describe 'nested attributes' do
    it { should accept_nested_attributes_for(:github_account) }
    it { should accept_nested_attributes_for(:user_token) }
    it { should accept_nested_attributes_for(:user_stat) }
  end

  describe 'scopes' do
    describe '.with_github_id' do
      let!(:user) { create(:user, :with_github_account) }
      let!(:other_user) { create(:user, :with_github_account) }

      before do
        user.github_account.update(github_id: 12345)
        other_user.github_account.update(github_id: 67890)
      end

      it 'finds users by github id' do
        expect(User.with_github_id(12345)).to include(user)
        expect(User.with_github_id(12345)).not_to include(other_user)
      end
    end
  end

  describe '#access_token' do
    let(:user) { create(:user, :with_access_token) }

    it 'returns the access token from the user_token' do
      expect(user.access_token).to eq('test_access_token')
    end

    context 'when user has no token' do
      let(:user) { create(:user) }

      it 'returns nil' do
        expect(user.access_token).to be_nil
      end
    end
  end

  describe '#issues' do
    let(:user) { create(:user, :with_github_account) }
    let!(:user_issue) { create(:issue, author_username: user.github_account.github_username) }
    let!(:other_issue) { create(:issue, author_username: 'other-author') }

    it 'returns issues authored by the user' do
      expect(user.issues).to include(user_issue)
      expect(user.issues).not_to include(other_issue)
    end
  end

  describe '#pull_requests' do
    let(:user) { create(:user, :with_github_account) }
    let!(:user_pr) { create(:pull_request, author_username: user.github_account.github_username) }
    let!(:other_pr) { create(:pull_request, author_username: 'other-author') }

    it 'returns pull requests authored by the user' do
      expect(user.pull_requests).to include(user_pr)
      expect(user.pull_requests).not_to include(other_pr)
    end
  end

  describe '#repositories' do
    let(:user) { create(:user, :with_github_account) }
    let!(:user_repo) { create(:github_repository, author_username: user.github_account.github_username) }
    let!(:other_repo) { create(:github_repository, author_username: 'other-author') }

    it 'returns repositories authored by the user' do
      expect(user.repositories).to include(user_repo)
      expect(user.repositories).not_to include(other_repo)
    end
  end
end
